-- following created based on
-- 1. http://rusanu.com/2007/04/25/reusing-conversations/
-- 2. https://docs.microsoft.com/en-us/sql/database-engine/configure-windows/sql-server-service-broker?view=sql-server-2017
-- 3. https://docs.microsoft.com/en-us/previous-versions/sql/sql-server-2008-r2/bb839489(v=sql.105)

use master;
go

-- enable broker for remit database
alter database remit set ENABLE_BROKER;
go

use remit;
go

-- create exported table
create table giros (
   id uniqueidentifier primary key,
   name varchar(100)
);
go

-- create message types
create message type SourceMessageType_giros validation = none;
create message type TargetMessageType_giros validation = none;
go

-- create contract
create contract ContractName_giros (SourceMessageType_giros sent by initiator, TargetMessageType_giros sent by target);
go

-- create queues
create queue SourceQueue_giros with status = on, poison_message_handling (status = off);
create queue TargetQueue_giros with status = on, poison_message_handling (status = off);
go

-- create services
create service SourceService_giros on queue SourceQueue_giros (ContractName_giros);
create service TargetService_giros on queue TargetQueue_giros (ContractName_giros);
go

alter procedure ConfigureQueuesForTable(@TableName SYSNAME)
as
begin
    declare @SourceQueueName as SYSNAME = concat(N'SourceQueue_', @TableName);
    declare @TargetQueueName as SYSNAME = concat(N'TargetQueue_', @TableName);
    declare @handle UNIQUEIDENTIFIER;

    BEGIN DIALOG CONVERSATION @handle
        FROM SERVICE @SourceQueueName
        TO SERVICE @TargetQueueName
        ON CONTRACT @TargetQueueName
        WITH ENCRYPTION = OFF;

     --create queue @TableName with status = on, poison_message_handling (status = off);
     --create queue @TargetQueueName with status = on, poison_message_handling (status = off);

end
go

CREATE TABLE [SessionConversations] (
	FromService SYSNAME NOT NULL,
	ToService SYSNAME NOT NULL,
	OnContract SYSNAME NOT NULL,
	Handle UNIQUEIDENTIFIER NOT NULL,
	PRIMARY KEY (FromService, ToService, OnContract),
	UNIQUE (Handle));
GO

CREATE PROCEDURE [usp_Send] (
    @fromService SYSNAME, @toService SYSNAME, @onContract SYSNAME, @messageType SYSNAME, @messageBody NVARCHAR(MAX)
)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @handle UNIQUEIDENTIFIER;
	DECLARE @counter INT;
	DECLARE @error INT;
	SELECT @counter = 1;
	BEGIN TRANSACTION;
	-- Will need a loop to retry in case the conversation is
	-- in a state that does not allow transmission
	--

	WHILE (1=1)
	BEGIN
		-- Seek an eligible conversation in [SessionConversations]
		--
		SELECT @handle = Handle
			FROM [SessionConversations]
			WHERE FromService = @fromService
			AND ToService = @toService
			AND OnContract = @OnContract;

		IF @handle IS NULL
		BEGIN
			-- Need to start a new conversation for the current @@spid
			--
			BEGIN DIALOG CONVERSATION @handle
				FROM SERVICE @fromService
				TO SERVICE @toService
				ON CONTRACT @onContract
				WITH ENCRYPTION = OFF;
			INSERT INTO [SessionConversations]
				(FromService, ToService, OnContract, Handle)
				VALUES
				(@fromService, @toService, @onContract, @handle);
		END;

		-- Attempt to SEND on the associated conversation
		--
		SEND ON CONVERSATION @handle MESSAGE TYPE @messageType (@messageBody);

		SELECT @error = @@ERROR;
		IF @error = 0
		BEGIN
			-- Successful send, just exit the loop
			--
			BREAK;
		END

		SELECT @counter = @counter+1;
		IF @counter > 10
		BEGIN
			-- We failed 10 times in a row, something must be broken
			--
			RAISERROR (
				N'Failed to SEND on a conversation for more than 10 times. Error %i.'
				, 16, 1, @error) WITH LOG;
			BREAK;
		END

		-- Delete the associated conversation from the table and try again
		--
		DELETE FROM [SessionConversations]
			WHERE Handle = @handle;
			SELECT @handle = NULL;
	END
	COMMIT;
END
GO

create trigger TriggerName_giros on [dbo].giros after insert
    as
        set nocount on;

        declare @row as nvarchar(4000);
        declare @message as nvarchar(4000);

        set @row = (select id, name from inserted for json auto, without_array_wrapper);
        set @message = (select id, row = @row, tracking_type = 'inserted' from inserted for json auto, without_array_wrapper);

        EXECUTE usp_Send N'SourceService_giros', N'TargetService_giros', N'ContractName_giros', N'SourceMessageType_giros', @message

go

use remit;
go

-- EXECUTE usp_Send N'SourceService_giros', N'TargetService_giros', N'ContractName_giros', N'SourceMessageType_giros', 'terefere'

-- DECLARE @counter int
-- SET @counter = 5000
-- WHILE @counter < 50000 BEGIN
--     insert into giros values (newid(), concat('arek', @counter));
--     SET @counter = @counter + 1
--     -- waitfor delay '00:00:00.010'
-- END
-- GO
--
-- select * from TargetQueue_giros;
-- select * from sys.transmission_queue;

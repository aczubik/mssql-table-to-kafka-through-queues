create database remit;
go

use master;
go

-- enable broker for remit database
alter database remit set ENABLE_BROKER;
go

use remit;
go

-- create message types
create message type SourceMessage validation = none;
create message type TargetMessage validation = none;
go

-- create contract
create contract MyContract (SourceMessage sent by initiator, TargetMessage sent by target);
go

-- create queues
create queue dbo.SourceQueue with status = on, poison_message_handling (status = off);
create queue dbo.TargetQueue with status = on, poison_message_handling (status = off);
go

-- create services
create service SourceService on queue dbo.SourceQueue (MyContract);
create service TargetService on queue dbo.TargetQueue (MyContract);
go

-- create debug table
create table debug_table (
    text nvarchar(100)
);
go

-- create TargetQueue listening procedure
create PROCEDURE OnMessageProc
AS
DECLARE @DlgHandle UNIQUEIDENTIFIER;
DECLARE @MessageBody NVARCHAR(100);
DECLARE @MessageTypeName sysname;

    WHILE (1=1)
    BEGIN

        BEGIN TRANSACTION;

        WAITFOR
            ( RECEIVE TOP(1)
                @DlgHandle = conversation_handle,
                @MessageBody = message_body,
                @MessageTypeName = message_type_name
            FROM TargetQueue
            ), TIMEOUT 500;


        IF (@@ROWCOUNT = 0)
            BEGIN
                ROLLBACK TRANSACTION;
                BREAK;
            END

        IF @MessageTypeName = N'SourceMessage'
            BEGIN
                -- I am not sure yet what is this reply for
                DECLARE @ReplyMsg NVARCHAR(100);
                SELECT @ReplyMsg = N'<ReplyMsg>Message for Initiator service.</ReplyMsg>';

                SEND ON CONVERSATION @DlgHandle
                    MESSAGE TYPE
                    [TargetMessage]
                    (@ReplyMsg);

                insert into debug_table values (CONCAT('Got message: ', @MessageBody));
            END
        ELSE IF @MessageTypeName = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'
            BEGIN
                END CONVERSATION @RecvReqDlgHandle;
                insert into debug_table values ('end dialog');
            END
        -- I don't know what happens in case of error. Will it be 're-consumed' or what?
        ELSE IF @RecvReqMsgName = N'http://schemas.microsoft.com/SQL/ServiceBroker/Error'
            BEGIN
                END CONVERSATION @RecvReqDlgHandle;
                insert into debug_table values ('conversation error');
            END

COMMIT TRANSACTION;

END
GO

-- procedure internal activation
ALTER QUEUE TargetQueue
    WITH ACTIVATION
    ( STATUS = ON,
    PROCEDURE_NAME = OnMessageProc,
    MAX_QUEUE_READERS = 10,
    EXECUTE AS SELF
    );
GO


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

create trigger TriggerName_giros on [dbo].giros after insert
    as
        set nocount on;

        declare @row as nvarchar(4000);
        declare @message as nvarchar(4000);

        set @row = (select id, name from inserted for json auto, without_array_wrapper);
        set @message = (select id, row = @row, tracking_type = 'inserted' from inserted for json auto, without_array_wrapper);

        declare @MyDialog UNIQUEIDENTIFIER;
        begin dialog conversation @MyDialog from service SourceService_giros to service 'TargetService_giros' on contract ContractName_giros with encryption = off;
        send on conversation @MyDialog message type SourceMessageType_giros (@message);
        end conversation @MyDialog;
go

--insert into giros values (newid(), 'arek');
--
-- DECLARE @counter int
-- SET @counter = 1300
-- WHILE @counter < 1400 BEGIN
--     insert into giros values(@counter, concat('arek_', @counter));
--     SET @counter = @counter + 1
--     waitfor delay '00:00:00.100'
-- END
-- GO

-- select * from TargetQueue_giros;
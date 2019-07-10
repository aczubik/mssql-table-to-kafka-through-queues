use master;
go

-- enable broker for remit database
alter database remit set ENABLE_BROKER;
go

use remit;
go

-- create exported table
create table users (
   id bigint primary key,
   name varchar(100)
);
go

-- create message types
create message type SourceMessageType_Users validation = none;
create message type TargetMessageType_Users validation = none;
go

-- create contract
create contract ContractName_Users (SourceMessageType_Users sent by initiator, TargetMessageType_Users sent by target);
go

-- create queues
create queue SourceQueue_Users with status = on, poison_message_handling (status = off);
create queue TargetQueue_Users with status = on, poison_message_handling (status = off);
go

-- create services
create service SourceService_Users on queue SourceQueue_Users (ContractName_Users);
create service TargetService_Users on queue TargetQueue_Users (ContractName_Users);
go

create trigger TriggerName_Users on [dbo].Users after insert
    as
        set nocount on;

        declare @row as nvarchar(4000);
        declare @message as nvarchar(4000);

        set @row = (select name from inserted for json auto, without_array_wrapper);
        set @message = (select id, row = @row, tracking_type = 'inserted' from inserted for json auto, without_array_wrapper);

        declare @MyDialog UNIQUEIDENTIFIER;
        begin dialog conversation @MyDialog from service SourceService_Users to service 'TargetService_Users' on contract ContractName_Users with encryption = off;
        send on conversation @MyDialog message type SourceMessageType_Users (@message);
        end conversation @MyDialog;
go

-- insert into users values (1, 'arek');
-- insert into users values (2, 'arek');
-- insert into users values (3, 'arek3');
-- insert into users values (4, 'arek');
-- insert into users values (5, 'arek');
-- insert into users values (6, 'arek1');
-- insert into users values (8, 'arek2');
-- insert into users values (8, 'arek');
-- insert into users values (9, 'arek');
-- insert into users values (10, 'arek');
-- insert into users values (11, 'arek');
-- insert into users values (12, 'arek');
-- insert into users values (13, 'arek');
-- insert into users values (14, 'arek');
-- insert into users values (15, 'arek');
-- insert into users values (16, 'arek');
-- insert into users values (17, 'arek');
-- insert into users values (18, 'arek');
-- insert into users values (19, 'arek');
-- insert into users values (19, 'arek');
-- insert into users values (21, 'arek');

-- DECLARE @counter int
-- SET @counter = 1300
-- WHILE @counter < 1400 BEGIN
--     insert into users values(@counter, concat('arek_', @counter));
--     SET @counter = @counter + 1
--     waitfor delay '00:00:00.100'
-- END
-- GO
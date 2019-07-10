use remit;
go

-- send messages
declare @MyDialog UNIQUEIDENTIFIER;
begin dialog conversation @MyDialog from service SourceService to service 'TargetService' on contract MyContract with encryption = off;
send on conversation @MyDialog message type SourceMessage (N'source message');
end conversation @MyDialog;
go


-- view messages in the queue
select convert(nvarchar(max), message_body) as message from TargetQueue_Users
go

-- receive messages
receive top(1) convert(nvarchar(max), message_body) as message_from_target from TargetQueue
go

receive convert(nvarchar(max), message_body) as message_from_target from TargetQueue
go


select * from SourceQueue_Users;
select * from TargetQueue_Users;
select * from debug_table;
select * from sys.transmission_queue;
select * from sys.dm_broker_activated_tasks;
SELECT * FROM sys.service_queues;

create table TargetQueue1 (
    conversation_handle bigint,
    message_body nvarchar(500),
    message_type_name nvarchar(500)
);
go

insert into users values (1, 'arek');
insert into users values (2, 'arek');
insert into users values (3, 'arek');
insert into users values (6, 'arek');

select * from qdebug;

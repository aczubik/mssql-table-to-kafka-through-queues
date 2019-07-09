-- send messages
declare @MyDialog UNIQUEIDENTIFIER;
begin dialog conversation @MyDialog from service SourceService to service 'TargetService' on contract MyContract with encryption = off;
send on conversation @MyDialog message type SourceMessage (N'source message');
end conversation @MyDialog;
go


-- view messages in the queue
select convert(nvarchar(max), message_body) as message from TargetQueue
go

-- receive messages
receive top(1) convert(nvarchar(max), message_body) as message_from_target from TargetQueue
go

receive convert(nvarchar(max), message_body) as message_from_target from TargetQueue
go

select * from debug_table;
select * from sys.transmission_queue;
select * from sys.dm_broker_activated_tasks;

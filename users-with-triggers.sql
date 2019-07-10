use remit;
go

-- create monitored table
create table users (
    id bigint,
    name nvarchar(100),
    constraint pk_users_id primary key (id)
);
go

-- create procedure pushing data to queue
create procedure dbo.SendToQueue
    @id as int,
    @value as nvarchar(100),
    @tracking_type as nvarchar(100)
as
    declare @MyDialog UNIQUEIDENTIFIER;
    begin dialog conversation @MyDialog from service SourceService to service 'TargetService' on contract MyContract with encryption = off;
    send on conversation @MyDialog message type SourceMessage (@value);
    end conversation @MyDialog
go

-- create insert trigger
create trigger dbo.users_trigger on dbo.users after insert
    as
    begin
        set nocount on;

        declare @id as int
        declare @value as nvarchar(100)
        declare @tracking_type as nvarchar(100)

        select @id = id, @value = name from inserted;
        set @tracking_type = 'insert';

        execute dbo.SendToQueue @id, @value, @tracking_type
    end
go

insert into users values (1, 'arek');
insert into users values (2, 'arek');
insert into users values (3, 'arek');
insert into users values (4, 'arek');
insert into users values (5, 'arek');

declare @a nvarchar(100);

delete from debug_table where 1=1;
select * from debug_table;
select * from sys.transmission_queue;
select * from TargetQueue;



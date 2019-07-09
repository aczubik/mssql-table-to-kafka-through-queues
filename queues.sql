create database remit;
go

use master;
go

alter database remit set ENABLE_BROKER;
go

use remit;
go

-- create message types
create message type SourceMessage validation = none;
create message type TargetMessage validation = none;
go

create contract MyContract (SourceMessage sent by initiator, TargetMessage sent by target);
go 

-- create queues
create queue dbo.SourceQueue;
create queue dbo.TargetQueue;
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
DECLARE @RecvReqDlgHandle UNIQUEIDENTIFIER;
DECLARE @RecvReqMsg NVARCHAR(100);
DECLARE @RecvReqMsgName sysname;

    insert into debug_table values ('before begin');

    WHILE (1=1)
    BEGIN

        BEGIN TRANSACTION;

        WAITFOR
            ( RECEIVE TOP(1)
                @RecvReqDlgHandle = conversation_handle,
                @RecvReqMsg = message_body,
                @RecvReqMsgName = message_type_name
            FROM TargetQueue
            ), TIMEOUT 5000;


        IF (@@ROWCOUNT = 0)
            BEGIN
                ROLLBACK TRANSACTION;
                BREAK;
            END

        IF @RecvReqMsgName =
           N'SourceMessage'
            BEGIN
                DECLARE @ReplyMsg NVARCHAR(100);
                SELECT @ReplyMsg =
                       N'<ReplyMsg>Message for Initiator service.</ReplyMsg>';

                SEND ON CONVERSATION @RecvReqDlgHandle
                    MESSAGE TYPE
                    [TargetMessage]
                    (@ReplyMsg);

                insert into debug_table values (CONCAT('Got message: ', @RecvReqMsg));
                insert into debug_table values ('sent reply');
            END
        ELSE IF @RecvReqMsgName =
                N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'
            BEGIN
                END CONVERSATION @RecvReqDlgHandle;
                insert into debug_table values ('end dialog');
            END
        ELSE IF @RecvReqMsgName =
                N'http://schemas.microsoft.com/SQL/ServiceBroker/Error'
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


#!/bin/bash

user=sa
password=Terefere123!

until /opt/mssql-tools/bin/sqlcmd -S 0.0.0.0 -U $user -P $password -q 'exit'; do
    echo '>>>> Waiting for database...'
    sleep 1
done

echo '>>>> Database server ready'

echo ">>>> Creating database..."
echo ""
/opt/mssql-tools/bin/sqlcmd -U sa -S 0.0.0.0 -U $user -P $password -i ./init.sql

echo ">>>> Creating schema..."
echo ""
for entry in "ddl/*.sql"
do
  echo executing $entry
  /opt/mssql-tools/bin/sqlcmd -S 0.0.0.0 -U sa -P $password -i $entry
done

echo ">>>> Creating data..."
echo ""
for entry in "dml/*.sql"
do
  echo executing $entry
  /opt/mssql-tools/bin/sqlcmd -S 0.0.0.0 -U sa -P $password -i $entry
done
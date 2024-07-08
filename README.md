# Integration Toolkit Command Line Application

## Overview

The `GenerateFile` application is a command line tool designed to extract records from a database, save them into text files, and update a journal table with the extracted records. It supports grouping records into separate files based on a specified column.

## Features

- Extracts records from a database and saves them into text files.
- Supports grouping records into multiple files based on a specified column.
- Updates a journal table with the extracted records.
- Configurable padding for columns.
- Progress bar display for long-running operations.
- Color-coded console output for better readability.

## Usage

### Command Line Parameters

GenerateFile --driver <DriverID> --server <Server> --database <Database> --username <UserName> --password <Password> --config <ColumnConfigFile> --query <SQLQueryFile> --outputpath <OutputPath> --out <OutputFilePrefix> --map <MappingFile> [--skipjournal] [--groupresults <ColumnName>]


### Parameters

- `--driver <DriverID>`: The database driver ID (e.g., `MSSQL`).
- `--server <Server>`: The server name or IP address.
- `--database <Database>`: The database name.
- `--username <UserName>`: The database user name.
- `--password <Password>`: The database user password.
- `--config <ColumnConfigFile>`: Path to the column configuration file.
- `--query <SQLQueryFile>`: Path to the SQL query file.
- `--outputpath <OutputPath>`: Path to the directory where output files will be saved.
- `--out <OutputFilePrefix>`: Prefix for the output file names.
- `--map <MappingFile>`: Path to the mapping file.
- `--skipjournal`: (Optional) Skip updating the export journal table.
- `--groupresults <ColumnName>`: (Optional) Column name to group results into separate files.

### Example Command

GenerateFile --driver MSSQL --server myserver.database.windows.net --database mydatabase --username myuser --password mypassword --config ./config/columns.cfg --query ./config/query.sql --outputpath ./output --out MYDATA --map ./config/mapping.map --groupresults prefix


## Configuration Files

### Column Configuration File

The column configuration file defines the padding for each column. Each line should contain the column name, padding direction (left or right), and the padding length.

Example (`columns.cfg`):

prefix left 25
code1 left 4
assetId left 25
code2 left 4
parentId left 75
code3 left 36


### SQL Query File

The SQL query file contains the SQL query used to extract records from the database.

Example (`query.sql`):
```sql
SELECT [prefix], [code1], [assetId], [code2], [parentId], [code3]
FROM [agresso].[CostFile]



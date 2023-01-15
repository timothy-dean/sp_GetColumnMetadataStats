# sp_GetColumnMetadataStats
SQL Server Stored Procedure to get table or view column metadata and statistics

```sql
USE [DBA]
GO

DECLARE @RC int
      , @DatabaseName sysname
      , @SchemaName sysname
      , @TableName sysname
      , @IncludeStats bit
      , @IncludeTopValues bit
      , @Debug bit

SET @DatabaseName = N'AdventureWorksDW2019';
SET @SchemaName = N'dbo';
SET @TableName = N'DimProduct';
SET @IncludeStats = 0;
SET @IncludeTopValues = 0;

EXECUTE @RC = [dbo].[sp_GetColumnMetadataStats] 
   @DatabaseName
  ,@SchemaName
  ,@TableName
  ,@IncludeStats
  ,@IncludeTopValues
  ,@Debug
GO
```

![image](https://user-images.githubusercontent.com/45572244/212561836-76d53411-450e-4f46-97ec-57147e2ee746.png)

## IncludeStats

Setting this flag add the following additional statistics columns to the output

count_distinct
count_empty
count_null
count_row
val_min
val_max
len_max

![image](https://user-images.githubusercontent.com/45572244/212561892-4c1fcf65-bb26-444b-9e00-eb4b6a6df980.png)

## IncludeTopValues

This flag adds top 10 values for each column ordered in descending order, with the count shown in parenthesis after each item.

The @IncludeStats flag must also be set.

![image](https://user-images.githubusercontent.com/45572244/212561958-90562b87-a17a-4ea5-a32e-b67d34de4190.png)






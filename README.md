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

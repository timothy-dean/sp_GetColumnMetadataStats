
/*
sp_GetColumnMetadataStats

SQL Server Stored Procedure to get column metadata and statistics from
a database table or view.

Copyright (C) 2023  Tim Dean

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

*/
CREATE PROCEDURE [dbo].[sp_GetColumnMetadataStats] 
	 @DatabaseName     sysname = null
   , @SchemaName       sysname = null
   , @TableName        sysname
   , @IncludeStats	   bit	   = 0
   , @IncludeTopValues bit     = 0
   , @Debug            bit     = 0
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @data_types_for_stats varchar(1000)
        = 'text,date,time,datetime2,datetimeoffset,tinyint,smallint,int,smalldatetime,real,money,datetime,float,ntext,bit,decimal,numeric,smallmoney,bigint,varchar,char,timestamp,nvarchar,nchar,sysname';

    DECLARE @sql             nvarchar(MAX) = ''
          , @max_row_seq     int
          , @current_row_seq int           = 1
		  , @do_column_stats bit
          , @column_name     sysname
		  , @data_type		 sysname

    IF OBJECT_ID('tempdb..#column_metadata') IS NOT NULL
        DROP TABLE #column_metadata;

    IF OBJECT_ID('tempdb..#column_stats') IS NOT NULL
        DROP TABLE #column_stats;

	IF OBJECT_ID('tempdb..#column_top_values') IS NOT NULL
        DROP TABLE #column_top_values;

    CREATE TABLE #column_metadata
    (
        row_seq int
      , [object_schema_name] nvarchar(128)
      , [object_name] nvarchar(128)
	  , column_id int
	  , column_name sysname
	  , data_type sysname
	  , max_length smallint
	  , [precision] tinyint
	  , scale tinyint
	  , is_nullable bit
	  , is_rowguidcol bit
	  , is_identity bit
	  , is_computed bit
	  , is_masked bit
    )

	CREATE TABLE #column_stats
	(
		column_name sysname
	  ,	count_row int
	  , count_distinct int
	  , count_null int
	  , count_empty int
	  , val_min nvarchar(max)
	  , val_max nvarchar(max)
	  , len_max int
	);

	CREATE TABLE #column_top_values
	(
		column_name sysname
	  , top_values nvarchar(max)
	);

	IF @DatabaseName IS NOT NULL
		SET @sql = N'USE ' + QUOTENAME(@DatabaseName) + nchar(13)

	SET @sql = @sql + N'INSERT INTO #column_metadata' + nchar(13) +
	                  N'SELECT ROW_NUMBER() OVER (PARTITION BY COL.[object_id] ORDER BY COL.column_id) AS row_seq' + nchar(13) +
	                  N'	 , OBJECT_SCHEMA_NAME(COL.[object_id])                                     AS [object_schema_name]' + nchar(13) +
			          N'	 , OBJECT_NAME(COL.[object_id])                                            AS [object_name]' + nchar(13) +
			          N'     , COL.column_id' + nchar(13) +
			          N'     , COL.[name]                                                              AS column_name' + nchar(13) +
			          N'     , TYP.[name]                                                              AS data_type' + nchar(13) +
			          N'     , COL.max_length' + nchar(13) +
			          N'     , COL.[precision]' + nchar(13) +
			          N'     , COL.scale' + nchar(13) +
			          N'     , COL.is_nullable' + nchar(13) +
			          N'     , COL.is_rowguidcol' + nchar(13) +
			          N'     , COL.is_identity' + nchar(13) +
			          N'     , COL.is_computed' + nchar(13) +
			          N'     , COL.is_masked' + nchar(13) +
			          N'FROM sys.columns AS COL' + nchar(13) +
			          N'INNER JOIN sys.types AS TYP ON (COL.user_type_id = TYP.user_type_id)' + nchar(13) +
			          N'WHERE COL.object_id = OBJECT_ID(N''' + ISNULL(QUOTENAME(@SchemaName) + '.', '') + QUOTENAME(@TableName) + ''')' + nchar(13) +
			          N'ORDER BY COL.column_id;'

    IF @Debug = 1
        SELECT @sql

    EXEC sp_executesql @sql;

	IF @IncludeStats = 1
	BEGIN
		SELECT @max_row_seq = MAX(row_seq)
		FROM #column_metadata;

		WHILE @current_row_seq <= @max_row_seq
		BEGIN

			SELECT @column_name     = MET.column_name
				 , @do_column_stats = CASE WHEN TYP_STAT.[value] IS NOT NULL THEN 1 ELSE 0 END
				 , @data_type	    = MET.data_type
			FROM #column_metadata AS MET
			LEFT JOIN STRING_SPLIT(@data_types_for_stats, ',') AS TYP_STAT ON (MET.data_type = TYP_STAT.[value])
			WHERE MET.row_seq = @current_row_seq;

			IF @do_column_stats = 1
			BEGIN

				IF @DatabaseName IS NOT NULL
					SET @sql = N'USE ' + QUOTENAME(@DatabaseName) + nchar(13)
				
				SET @sql = @sql + N'INSERT INTO #column_stats' + nchar(13) +
				                  N'SELECT ''' + @column_name + ''' AS column_name' + nchar(13) +
								  N'     , COUNT(*) AS count_row' + nchar(13) +
								  N'     , COUNT(DISTINCT ' + QUOTENAME(@column_name) + ') AS count_distinct' + nchar(13) +
								  N'     , SUM(CASE WHEN ' + QUOTENAME(@column_name) + ' IS NULL THEN 1 ELSE 0 END) AS count_null' + nchar(13) +
								  N'     , SUM(CASE WHEN ' + QUOTENAME(@column_name) + ' = '''' THEN 1 ELSE 0 END) AS count_empty' + nchar(13);

				IF @data_type = 'bit'
					SET @sql = @sql + N'     , MIN(CAST(' + QUOTENAME(@column_name) + N' AS char(1))) AS value_min' + nchar(13) +
					                  N'     , MAX(CAST(' + QUOTENAME(@column_name) + N' AS char(1))) AS value_max' + nchar(13);
				ELSE
					SET @sql = @sql + N'     , MIN(' + QUOTENAME(@column_name) + N') AS value_min' + nchar(13) +
					                  N'     , MAX(' + QUOTENAME(@column_name) + N') AS value_max' + nchar(13);

				IF @data_type LIKE '%char' OR @data_type LIKE '%text'
					SET @sql = @sql + N'     , MAX(LEN(' + QUOTENAME(@column_name) + N')) AS len_max' + nchar(13);
				ELSE
					SET @sql = @sql + N'     , -1 AS len_max' + nchar(13);

				SET @sql = @sql + N'FROM ' + ISNULL(QUOTENAME(@SchemaName) + '.','') + QUOTENAME(@TableName) + N';';

				EXEC sp_executesql @sql;

				IF @IncludeTopValues = 1
				BEGIN

					IF @DatabaseName IS NOT NULL
						SET @sql = N'USE ' + QUOTENAME(@DatabaseName) + nchar(13)
				
					SET @sql = @sql + N'INSERT INTO #column_top_values' + nchar(13) +
						              N'SELECT ''' + @column_name + ''' AS column_name' + nchar(13) +
									  N'	 , STRING_AGG(GRP.column_value + ''('' + GRP.total_count + '')'','','') AS top_values' + nchar(13) +
									  N'FROM (' + nchar(13) +
									  N'	SELECT TOP(10) CAST(' + QUOTENAME(@column_name) + N' AS nvarchar(MAX)) AS column_value' + nchar(13) +
									  N'         , CAST(COUNT(*) AS varchar(10)) AS total_count' + nchar(13) +
									  N'	FROM ' + ISNULL(QUOTENAME(@SchemaName) + '.','') + QUOTENAME(@TableName) + nchar(13) +
									  N'    GROUP BY ' + QUOTENAME(@column_name) + nchar(13) +
									  N'    HAVING COUNT(*) >= 1' + nchar(13) +
									  N'    ORDER BY COUNT(*) DESC' + nchar(13) +
									  N'	) AS GRP;';

					EXEC sp_executesql @sql;
				END
			END

			SET @current_row_seq = @current_row_seq + 1
		END /* WHILE @current_row_seq <= @max_row_seq  */
	
		SET @sql = N'SELECT CM.row_seq' + nchar(13) +
		           N'	  , CM.[object_schema_name]' + nchar(13) +
				   N'     , CM.[object_name]' + nchar(13) + 
				   N'     , CM.column_id' + nchar(13) +
				   N'     , CM.column_name' + nchar(13) +
				   N'     , CM.data_type' + nchar(13) +
				   N'     , CM.max_length' + nchar(13) +
				   N'     , CM.[precision]' + nchar(13) +
				   N'     , CM.scale' + nchar(13) +
				   N'     , CM.is_nullable' + nchar(13) +
				   N'     , CM.is_rowguidcol' + nchar(13) +
				   N'     , CM.is_identity' + nchar(13) +
				   N'     , CM.is_computed' + nchar(13) +
				   N'     , CM.is_masked' + nchar(13) +
				   N'     , ISNULL(CS.count_distinct, ''-1'') AS count_distinct' + nchar(13) +
				   N'     , ISNULL(CS.count_empty, ''-1'') AS count_empty' + nchar(13) +
				   N'     , ISNULL(CS.count_null, ''-1'') AS count_null' + nchar(13) +
				   N'     , ISNULL(CS.count_row, ''-1'') AS count_row' + nchar(13) +
				   N'     , ISNULL(CS.val_min, ''N/A'') AS val_min' + nchar(13) +
				   N'     , ISNULL(CS.val_max, ''N/A'') AS val_max' + nchar(13) +
				   N'     , ISNULL(CS.len_max, ''-1'') AS len_max' + nchar(13)

		IF @IncludeTopValues = 1
			SET @sql = @sql + N'      , ISNULL(CTV.top_values, ''N/A'') AS top_values' + nchar(13);

		SET @sql = @sql + N'FROM #column_metadata AS CM' + nchar(13) +
				          N'LEFT JOIN #column_stats AS CS ON (CM.column_name = CS.column_name)' + nchar(13);

		IF @IncludeTopValues = 1
			SET @sql = @sql + N'LEFT JOIN #column_top_values AS CTV ON (CM.column_name = CTV.column_name);';
		ELSE
			SET @sql = @sql + N';';

		EXEC sp_executesql @sql;
	
	END  /* IF @IncludeStats = 1 */
	ELSE
	BEGIN
		SELECT CM.row_seq
		 	 , CM.[object_schema_name]
			 , CM.[object_name]
			 , CM.column_id
			 , CM.column_name
			 , CM.data_type
			 , CM.max_length
			 , CM.[precision]
			 , CM.scale
			 , CM.is_nullable
			 , CM.is_rowguidcol
			 , CM.is_identity
			 , CM.is_computed
			 , CM.is_masked
		FROM #column_metadata AS CM;
	END

END
GO



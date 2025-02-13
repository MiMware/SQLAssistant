SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO
ALTER   PROCEDURE dbo.Json_SelectResult
    @JSON TJSON = NULL, @WHERE TSTRING = NULL, @OrderBy TSTRING = NULL
AS
BEGIN

    DECLARE @FirstRow NVARCHAR(MAX) = (SELECT TOP (1)   value FROM  OPENJSON (@JSON));
    DECLARE @ColumnCommand NVARCHAR(MAX);
    DECLARE @ColumnNullCommand NVARCHAR(MAX);
    DECLARE @Command NVARCHAR(MAX);

    -- A table for Json key,value and type
    DECLARE @Columns TABLE (Position INT IDENTITY PRIMARY KEY,
        ColumnName sysname NOT NULL UNIQUE,
        JsonDatatype INT NOT NULL,
        SqlDatatype VARCHAR(30) NOT NULL);
    
	-- Find datatypes
    INSERT INTO @Columns (ColumnName, JsonDatatype, SqlDatatype)
    SELECT  [key], type, CASE type
                             WHEN 0 -- NULL
                                 THEN 'varchar(1)'
                             WHEN 1 -- String value
                                 THEN 'nvarchar(2000)'
                             WHEN 2 -- Int, double, float
                                 THEN 'float'
                             WHEN 3 -- Boolean
                                 THEN 'bit'
                         /*4 and 5 is array and object*/
                         END
      FROM  OPENJSON (@FirstRow);

    -- Create table columns
    SET @ColumnCommand = N'(' + (   SELECT  CHAR (13) + CHAR (10) + CHAR (9) + ColumnName + ' ' + c.SqlDatatype + CASE
                                                                                                                      WHEN c.Position < COUNT (*) OVER ()
                                                                                                                          THEN ',' ELSE ''
                                                                                                                  END
                                      FROM  @Columns c
                                     ORDER BY c.Position
                                    FOR XML PATH (''), TYPE).value ('.', 'nvarchar(max)') + CHAR (13) + CHAR (10) + N')';

    -- Where statement table columns
    SET @ColumnNullCommand = N'' + (   SELECT   CHAR (13) + CHAR (10) + CHAR (9) + ColumnName + ' IS NULL AND'
                                         FROM   @Columns c
                                        ORDER BY c.Position
                                       FOR XML PATH (''), TYPE).value ('.', 'nvarchar(max)') + CHAR (13) + CHAR (10) + N'';
    SET @ColumnNullCommand = LEFT(@ColumnNullCommand, LEN (@ColumnNullCommand) - 5);

    -- Create table
    SET @Command = N'CREATE TABLE #Temp ' + @ColumnCommand + CHAR (13) + CHAR (10) + N' ';
    -- Insert command
    SET @Command = @Command + N'INSERT INTO #Temp SELECT * FROM OPENJSON(@JSON) WITH' + @ColumnCommand + CHAR (13) + CHAR (10) + N'';

	IF @WHERE IS NOT NULL
		SET @Command = @Command + CHAR (13) + CHAR (10) + N' Where ' + @WHERE +' ';

	IF @OrderBy  IS NOT NULL
		SET @Command = @Command + CHAR (13) + CHAR (10) + N' Order by ' + @OrderBy +' ';
    -- Set output command
    SET @Command =
        @Command + N'SELECT * FROM #Temp'

    EXEC sp_executesql @Command, N'@JSON NVARCHAR(MAX)', @JSON

END;
GO

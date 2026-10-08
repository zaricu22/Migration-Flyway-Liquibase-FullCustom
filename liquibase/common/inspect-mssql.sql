-- Every column Liquibase created, with the REAL type SQL Server ended up with.
SET NOCOUNT ON;
SELECT o.name AS table_name,
       c.name AS column_name,
       TYPE_NAME(c.user_type_id) +
       CASE
           WHEN TYPE_NAME(c.user_type_id) IN ('varchar', 'char', 'varbinary', 'binary')
               THEN '(' + CASE WHEN c.max_length = -1 THEN 'max' ELSE CAST(c.max_length AS varchar(10)) END + ')'
           WHEN TYPE_NAME(c.user_type_id) IN ('nvarchar', 'nchar')
               THEN '(' + CASE WHEN c.max_length = -1 THEN 'max' ELSE CAST(c.max_length / 2 AS varchar(10)) END + ')'
           WHEN TYPE_NAME(c.user_type_id) IN ('decimal', 'numeric')
               THEN '(' + CAST(c.precision AS varchar(5)) + ',' + CAST(c.scale AS varchar(5)) + ')'
           WHEN TYPE_NAME(c.user_type_id) IN ('datetime2', 'datetimeoffset', 'time')
               THEN '(' + CAST(c.scale AS varchar(5)) + ')'
           ELSE ''
       END AS type,
       CASE WHEN c.is_nullable = 1 THEN 'YES' ELSE 'NO' END AS nullable,
       OBJECT_DEFINITION(c.default_object_id) AS default_value,
       CASE WHEN c.is_identity = 1 THEN 'IDENTITY' WHEN c.is_computed = 1 THEN 'COMPUTED' ELSE '' END AS extra
FROM sys.columns c
JOIN sys.objects o ON o.object_id = c.object_id
WHERE o.type IN ('U', 'V')
  AND o.name NOT LIKE 'DATABASECHANGELOG%'
ORDER BY o.name, c.column_id;

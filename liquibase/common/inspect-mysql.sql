-- Every column Liquibase created, with the REAL type MySQL ended up with.
SELECT TABLE_NAME     AS table_name,
       COLUMN_NAME    AS column_name,
       COLUMN_TYPE    AS type,
       IS_NULLABLE    AS nullable,
       COLUMN_DEFAULT AS default_value,
       EXTRA          AS extra
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME NOT LIKE 'DATABASECHANGELOG%'
ORDER BY TABLE_NAME, ORDINAL_POSITION;

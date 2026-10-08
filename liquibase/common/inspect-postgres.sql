-- Every column Liquibase created, with the REAL type PostgreSQL ended up with.
SELECT c.relname                                  AS table_name,
       a.attname                                  AS column_name,
       format_type(a.atttypid, a.atttypmod)       AS type,
       CASE WHEN a.attnotnull THEN 'NO' ELSE 'YES' END AS nullable,
       pg_get_expr(d.adbin, d.adrelid)            AS default_value,
       CASE a.attidentity WHEN 'a' THEN 'ALWAYS' WHEN 'd' THEN 'BY DEFAULT' ELSE '' END AS identity,
       CASE a.attgenerated WHEN 's' THEN 'STORED' ELSE '' END AS generated
FROM pg_attribute a
JOIN pg_class c      ON c.oid = a.attrelid
JOIN pg_namespace n  ON n.oid = c.relnamespace
LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'v')
  AND a.attnum > 0 AND NOT a.attisdropped
  AND c.relname NOT LIKE 'databasechangelog%'
ORDER BY c.relname, a.attnum;

SET NOCOUNT ON;
SELECT id, title, body, body_naive,
       CASE WHEN body = body_naive THEN 1 ELSE 0 END AS naive_intact
FROM article ORDER BY id;
-- varchar uses the code page of this collation (Latin1): everything else becomes '?'
SELECT DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS db_collation;

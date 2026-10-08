SET NOCOUNT ON;
SELECT DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS db_collation;
-- Names as stored:
SELECT table_name, column_name FROM information_schema.columns
WHERE table_name NOT LIKE 'DATABASECHANGELOG%' ORDER BY 1, 2;
-- Case-insensitive collation: every spelling works
SELECT * FROM customerorder;
SELECT * FROM CUSTOMERINVOICE;

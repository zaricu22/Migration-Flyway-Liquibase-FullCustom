SET NOCOUNT ON;
-- Tables left behind:
SELECT name AS table_name FROM sys.tables WHERE name NOT LIKE 'DATABASECHANGELOG%' ORDER BY 1;
-- Recorded changesets:
SELECT id, exectype FROM DATABASECHANGELOG ORDER BY orderexecuted;

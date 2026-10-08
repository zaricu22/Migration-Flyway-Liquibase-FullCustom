-- Tables left behind:
SELECT table_name FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name NOT LIKE 'DATABASECHANGELOG%' ORDER BY 1;
-- Recorded changesets:
SELECT id, exectype FROM DATABASECHANGELOG ORDER BY orderexecuted;

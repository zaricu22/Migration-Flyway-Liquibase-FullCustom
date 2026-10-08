\echo 'Tables left behind:'
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name NOT LIKE 'databasechangelog%' ORDER BY 1;
\echo 'Recorded changesets:'
SELECT id, exectype FROM databasechangelog ORDER BY orderexecuted;

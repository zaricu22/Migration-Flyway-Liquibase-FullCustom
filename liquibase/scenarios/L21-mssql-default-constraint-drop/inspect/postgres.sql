\echo 'Recorded changesets:'
SELECT id, exectype FROM databasechangelog ORDER BY orderexecuted;

\echo 'Recorded changesets (with tag, labels, contexts):'
SELECT id, exectype, tag, labels, contexts FROM databasechangelog ORDER BY orderexecuted;
\echo 'Products:'
SELECT * FROM product ORDER BY id;

-- Shows how a failed CREATE INDEX CONCURRENTLY leaves an INVALID index behind.
\set ON_ERROR_STOP off

\echo '--- A UNIQUE index on a column full of duplicates fails half-way...'
CREATE UNIQUE INDEX CONCURRENTLY orders_status_uq ON orders (status);

\echo '--- ...but the index object still exists, marked INVALID:'
SELECT c.relname AS index_name, i.indisvalid, i.indisready
FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
WHERE i.indrelid = 'orders'::regclass;

\echo '--- The planner ignores it, but every write still maintains it. Find all invalid indexes:'
SELECT indexrelid::regclass AS invalid_index FROM pg_index WHERE NOT indisvalid;

\echo '--- Cleanup'
DROP INDEX CONCURRENTLY IF EXISTS orders_status_uq;

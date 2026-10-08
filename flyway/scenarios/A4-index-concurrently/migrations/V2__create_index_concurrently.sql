-- CREATE INDEX CONCURRENTLY builds the index without blocking writes (a plain CREATE INDEX
-- blocks INSERT/UPDATE/DELETE for the whole build). It cannot run inside a transaction, so
-- this migration is marked non-transactional in V2__create_index_concurrently.sql.conf.
--
-- If a concurrent build fails (e.g. it's cancelled or hits a deadlock), PostgreSQL leaves an
-- INVALID index behind. "CREATE INDEX CONCURRENTLY IF NOT EXISTS" would then silently skip and
-- leave you with an index that is maintained on every write but never used for reads.
-- Dropping any leftover first makes the migration safe to re-run after a failure.
DROP INDEX CONCURRENTLY IF EXISTS orders_customer_id_idx;
CREATE INDEX CONCURRENTLY orders_customer_id_idx ON orders (customer_id);

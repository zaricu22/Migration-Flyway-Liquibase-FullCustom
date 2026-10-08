-- Step 1: build the unique index without blocking writes (non-transactional, see .conf).
-- "ALTER TABLE ... ADD CONSTRAINT ... UNIQUE (email)" would build the same index while
-- holding a lock that blocks all writes for the whole build.
DROP INDEX CONCURRENTLY IF EXISTS customer_email_uq;
CREATE UNIQUE INDEX CONCURRENTLY customer_email_uq ON customer (email);

-- Step 3: on a partitioned table, every PRIMARY KEY / UNIQUE constraint must include the
-- partition key. The new PK will be (id, created_at), so the existing table needs a matching
-- unique index BEFORE the switch, or ATTACH would build it under an exclusive lock.
-- CONCURRENTLY: no write lock, but can't run in a transaction (see the .conf file, A4).
-- It is slow but not blocking, we run it before the switch.
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS event_id_created_at_key ON event (id, created_at);   -- need for PARTITION rule

-- Even an "instant" ALTER TABLE needs an ACCESS EXCLUSIVE lock for a moment. If a long-running
-- query (report, backup, forgotten transaction) holds any lock on the table, the ALTER waits,
-- and every new query on the table queues up BEHIND the waiting ALTER. A 1 ms change turns into
-- an outage that lasts as long as the long query.
--
-- lock_timeout makes the migration give up quickly instead. Retry later.
-- SET LOCAL (not SET): it applies only to this migration's transaction. A plain SET would stay
-- active on Flyway's connection for all following migrations.
SET LOCAL lock_timeout = '3s';

-- Optional second guard: cap how long the statement itself may run.
SET LOCAL statement_timeout = '30s';

ALTER TABLE customer ADD COLUMN loyalty_points integer;

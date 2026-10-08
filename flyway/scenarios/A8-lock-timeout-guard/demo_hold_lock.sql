-- Simulates a long-running report: holds an ACCESS SHARE lock (what every SELECT takes)
-- on customer for 20 seconds.
\echo 'Holding a lock on customer for 20 seconds...'
BEGIN;
SELECT count(*) FROM customer;
SELECT pg_sleep(20);
COMMIT;
\echo 'Lock released.'

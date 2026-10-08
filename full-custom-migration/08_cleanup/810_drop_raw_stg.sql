-- CLEANUP, after the go-live has been accepted and the retention period is over:
-- drop the working layers and the connection to the old system.
-- mig.* stays: it is the audit trail (what was rejected and why, old key -> new id, every check).
DROP SCHEMA IF EXISTS stg CASCADE;
DROP SCHEMA IF EXISTS raw CASCADE;
DROP SCHEMA IF EXISTS src CASCADE;
DROP SERVER IF EXISTS legacy_srv CASCADE;
DROP PROCEDURE IF EXISTS mig.load_orders(int);

\echo 'Remaining migration schemas:'
SELECT nspname AS schema FROM pg_namespace WHERE nspname IN ('raw', 'stg', 'src', 'mig');

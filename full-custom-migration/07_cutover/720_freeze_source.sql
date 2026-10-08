-- CUTOVER step 1: FREEZE the old system, so nothing changes in it after the final delta.
-- Runs in the new database (shop); ALTER DATABASE works on any database of the server.
--
-- default_transaction_read_only = on: every NEW session in legacy_shop is read-only, so the final
-- delta reads a source that can't change anymore. Existing sessions keep their old setting, so they
-- are disconnected. In real life: stop the old application first, then freeze. The setting is a
-- guard, not security: a session could switch it off again; revoking write privileges is stricter.
-- Undo (NO-GO): ./run.sh unfreeze (07_cutover/729_unfreeze_source.sql)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM mig.run WHERE kind = 'full' AND status = 'DONE') THEN
        RAISE EXCEPTION 'No successful full run (or it was rolled back): run ./run.sh all first. Source NOT frozen.';
    END IF;
END $$;

ALTER DATABASE legacy_shop SET default_transaction_read_only = on;

SELECT count(pg_terminate_backend(pid)) AS sessions_disconnected
FROM pg_stat_activity
WHERE datname = 'legacy_shop' AND pid <> pg_backend_pid();

\echo 'Old system frozen: legacy_shop is read-only for new sessions.'

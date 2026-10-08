\echo '--- Migration history (checksum = what was in the file when it ran, or after a repair)'
SELECT installed_rank, version, description, checksum, success FROM flyway_schema_history ORDER BY installed_rank;

\echo '--- What the database really has'
SELECT column_name, column_default FROM information_schema.columns
WHERE table_schema = current_schema() AND table_name = 'orders' AND column_name = 'status';

-- Expected default: 'open' only if V3 ran, otherwise 'new' (what the ORIGINAL V2 created).
-- After "repair" of the edited V2 this still says 'new': the edit was accepted, never executed.
-- A fresh database built from the edited files would get 'open' -> the environments have drifted.
DO $$
DECLARE
    v3       boolean := EXISTS (SELECT 1 FROM flyway_schema_history WHERE version = '3' AND success);
    expected text    := CASE WHEN v3 THEN '''open''::text' ELSE '''new''::text' END;
    actual   text    := (SELECT column_default FROM information_schema.columns
                         WHERE table_schema = current_schema() AND table_name = 'orders' AND column_name = 'status');
BEGIN
    IF actual IS DISTINCT FROM expected THEN
        RAISE EXCEPTION 'FAIL: status default is %, expected % (V3 applied: %)', actual, expected, v3;
    END IF;
    RAISE NOTICE 'OK: status default % matches the applied migrations (V3 applied: %)', actual, v3;
END $$;

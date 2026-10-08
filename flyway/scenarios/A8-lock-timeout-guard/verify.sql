\echo '--- Columns of customer'
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema = current_schema() AND table_name = 'customer' ORDER BY ordinal_position;

\echo '--- lock_timeout was SET LOCAL, so it did not leak into the session (0 = no timeout)'
SHOW lock_timeout;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = current_schema() AND table_name = 'customer' AND column_name = 'loyalty_points') THEN
        RAISE EXCEPTION 'FAIL: loyalty_points missing (V2 not applied yet?)';
    END IF;
    RAISE NOTICE 'OK: loyalty_points added';
END $$;

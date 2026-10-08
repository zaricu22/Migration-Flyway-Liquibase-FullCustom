\echo '--- Columns of customer'
SELECT column_name, is_nullable FROM information_schema.columns
WHERE table_schema = current_schema() AND table_name = 'customer' ORDER BY ordinal_position;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = current_schema() AND table_name = 'customer' AND column_name = 'mail') THEN
        RAISE EXCEPTION 'FAIL: old column mail still exists';
    END IF;
    IF EXISTS (SELECT 1 FROM customer WHERE email IS NULL) THEN
        RAISE EXCEPTION 'FAIL: rows without email';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'customer'::regclass AND NOT tgisinternal) THEN
        RAISE EXCEPTION 'FAIL: sync trigger left behind';
    END IF;
    RAISE NOTICE 'OK: mail -> email completed, % rows, no leftovers', (SELECT count(*) FROM customer);
END $$;

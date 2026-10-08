\echo '--- country_code column'
SELECT column_name, is_nullable, column_default FROM information_schema.columns
WHERE table_schema = current_schema() AND table_name = 'customer' AND column_name = 'country_code';

\echo '--- CHECK constraints left on customer (expected: none)'
SELECT conname FROM pg_constraint WHERE conrelid = 'customer'::regclass AND contype = 'c';

DO $$
BEGIN
    IF NOT (SELECT attnotnull FROM pg_attribute
            WHERE attrelid = 'customer'::regclass AND attname = 'country_code') THEN
        RAISE EXCEPTION 'FAIL: country_code is still nullable';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'customer'::regclass AND contype = 'c') THEN
        RAISE EXCEPTION 'FAIL: helper CHECK constraint left behind';
    END IF;
    RAISE NOTICE 'OK: country_code is NOT NULL, helper constraint removed';
END $$;

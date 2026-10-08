\echo '--- Remaining relations'
SELECT relname, relkind FROM pg_class
WHERE relnamespace = current_schema()::regnamespace AND relkind IN ('r', 'v') AND relname NOT LIKE 'flyway%'
ORDER BY relname;

\echo '--- The dropped column is still in the catalog, marked attisdropped (its data is not reclaimed yet)'
SELECT attnum, attname, attisdropped FROM pg_attribute
WHERE attrelid = 'customer'::regclass AND attnum > 0 ORDER BY attnum;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = current_schema() AND table_name = 'customer' AND column_name = 'legacy_code') THEN
        RAISE EXCEPTION 'FAIL: legacy_code still exists';
    END IF;
    IF to_regclass('customer_legacy_login') IS NOT NULL OR to_regclass('_deprecated_customer_legacy_login') IS NOT NULL THEN
        RAISE EXCEPTION 'FAIL: legacy table still exists';
    END IF;
    IF to_regclass('customer_export') IS NULL THEN
        RAISE EXCEPTION 'FAIL: the view should have survived (recreated without the column)';
    END IF;
    RAISE NOTICE 'OK: column and table removed, the dependent view kept working';
END $$;

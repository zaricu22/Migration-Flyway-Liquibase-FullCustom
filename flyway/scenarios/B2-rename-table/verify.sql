\echo '--- Relations in the schema'
SELECT c.relname, c.relkind FROM pg_class c
WHERE c.relnamespace = current_schema()::regnamespace AND c.relname NOT LIKE 'flyway%'
ORDER BY c.relname;

DO $$
BEGIN
    IF to_regclass('item') IS NOT NULL THEN
        RAISE EXCEPTION 'FAIL: item still exists';
    END IF;
    IF to_regclass('product') IS NULL THEN
        RAISE EXCEPTION 'FAIL: product missing';
    END IF;
    RAISE NOTICE 'OK: item -> product, compat view removed, % rows', (SELECT count(*) FROM product);
END $$;

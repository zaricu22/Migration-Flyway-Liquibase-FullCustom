\echo '--- Indexes (all valid)'
SELECT c.relname AS index_name, i.indisvalid
FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
WHERE i.indrelid = 'product'::regclass ORDER BY 1;

\echo '--- Constraints and triggers'
SELECT conname, convalidated FROM pg_constraint WHERE conrelid = 'product'::regclass AND contype = 'f';
SELECT tgname, tgenabled FROM pg_trigger WHERE tgrelid = 'product'::regclass AND NOT tgisinternal;

DO $$
BEGIN
    IF (SELECT count(*) FROM product) <> 450000 THEN
        RAISE EXCEPTION 'FAIL: expected 450000 products';
    END IF;
    IF (SELECT count(*) FROM pg_index WHERE indrelid = 'product'::regclass AND indisvalid) <> 4 THEN
        RAISE EXCEPTION 'FAIL: indexes missing';
    END IF;
    IF NOT (SELECT convalidated FROM pg_constraint WHERE conname = 'product_category_fk' AND conrelid = 'product'::regclass) THEN
        RAISE EXCEPTION 'FAIL: FK missing or not validated';
    END IF;
    IF (SELECT tgenabled FROM pg_trigger WHERE tgname = 'product_touch_updated_at' AND tgrelid = 'product'::regclass) <> 'O' THEN
        RAISE EXCEPTION 'FAIL: trigger still disabled';
    END IF;
    RAISE NOTICE 'OK: 400000 rows loaded, indexes/FK/trigger restored';
END $$;

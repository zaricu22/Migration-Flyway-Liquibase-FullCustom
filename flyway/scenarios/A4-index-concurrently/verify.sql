\echo '--- Index state'
SELECT c.relname AS index_name, i.indisvalid
FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
WHERE i.indrelid = 'orders'::regclass;

\echo '--- The planner uses the new index'
EXPLAIN (COSTS OFF) SELECT * FROM orders WHERE customer_id = 42;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_index
                   WHERE indexrelid = 'orders_customer_id_idx'::regclass AND indisvalid) THEN
        RAISE EXCEPTION 'FAIL: orders_customer_id_idx missing or invalid';
    END IF;
    RAISE NOTICE 'OK: orders_customer_id_idx exists and is valid';
END $$;

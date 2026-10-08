\echo '--- Statuses in use'
SELECT status_code, count(*) FROM orders GROUP BY 1 ORDER BY 1;

DO $$
BEGIN
    IF to_regtype('order_status') IS NOT NULL THEN
        RAISE EXCEPTION 'FAIL: enum type order_status still exists';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = current_schema() AND table_name = 'orders' AND column_name = 'status') THEN
        RAISE EXCEPTION 'FAIL: old enum column still exists';
    END IF;
    IF EXISTS (SELECT 1 FROM orders WHERE status_code = 'on_hold')
       OR EXISTS (SELECT 1 FROM order_status_code WHERE code = 'on_hold') THEN
        RAISE EXCEPTION 'FAIL: on_hold not retired';
    END IF;
    IF NOT (SELECT convalidated FROM pg_constraint WHERE conname = 'orders_status_code_fk'
            AND conrelid = 'orders'::regclass) THEN
        RAISE EXCEPTION 'FAIL: FK to the lookup table not validated';
    END IF;
    RAISE NOTICE 'OK: enum replaced by lookup table, on_hold retired, % orders', (SELECT count(*) FROM orders);
END $$;

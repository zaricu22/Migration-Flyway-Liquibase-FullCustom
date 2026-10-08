\echo '--- Constraints (all validated)'
SELECT conrelid::regclass AS table_name, conname, convalidated
FROM pg_constraint WHERE conrelid IN ('orders'::regclass, 'customer'::regclass) AND contype IN ('f', 'c');

\echo '--- Quarantined rows'
SELECT reason, count(*) FROM orders_rejected GROUP BY reason;

\echo '--- Status distribution after cleanup'
SELECT status, count(*) FROM orders GROUP BY status ORDER BY status;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint
               WHERE conrelid IN ('orders'::regclass, 'customer'::regclass) AND contype IN ('f', 'c') AND NOT convalidated) THEN
        RAISE EXCEPTION 'FAIL: unvalidated constraint left';
    END IF;
    IF (SELECT count(*) FROM orders) + (SELECT count(*) FROM orders_rejected) <> 50000 THEN
        RAISE EXCEPTION 'FAIL: rows lost (orders + rejected <> 50000)';
    END IF;
    RAISE NOTICE 'OK: all constraints valid, no rows lost (% kept, % quarantined)',
        (SELECT count(*) FROM orders), (SELECT count(*) FROM orders_rejected);
END $$;

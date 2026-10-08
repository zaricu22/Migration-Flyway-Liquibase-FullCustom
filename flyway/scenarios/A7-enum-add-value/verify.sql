\echo '--- Enum values in sort order'
SELECT enumlabel, enumsortorder FROM pg_enum
WHERE enumtypid = 'order_status'::regtype ORDER BY enumsortorder;

\echo '--- Orders per status'
SELECT status, count(*) FROM orders GROUP BY status ORDER BY status;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM orders WHERE status = 'cancelled') THEN
        RAISE EXCEPTION 'FAIL: new enum value not in use';
    END IF;
    IF NOT ('paid'::order_status < 'cancelled' AND 'cancelled'::order_status < 'shipped') THEN
        RAISE EXCEPTION 'FAIL: wrong sort position';
    END IF;
    RAISE NOTICE 'OK: cancelled added between paid and shipped, and in use';
END $$;

\echo '--- Sample'
SELECT id, order_number FROM orders ORDER BY id LIMIT 3;

DO $$
DECLARE
    missing bigint;
    wrong   bigint;
BEGIN
    SELECT count(*) INTO missing FROM orders WHERE order_number IS NULL;
    SELECT count(*) INTO wrong   FROM orders WHERE order_number <> 'ORD-' || lpad(id::text, 10, '0');
    IF missing > 0 OR wrong > 0 THEN
        RAISE EXCEPTION 'FAIL: % rows missing, % rows wrong', missing, wrong;
    END IF;

    INSERT INTO orders (created_at, amount_cents) VALUES (now(), 100);
    IF (SELECT order_number FROM orders ORDER BY id DESC LIMIT 1) IS NULL THEN
        RAISE EXCEPTION 'FAIL: new rows do not get an order_number';
    END IF;
    RAISE NOTICE 'OK: all % rows backfilled, new rows filled by the trigger', (SELECT count(*) FROM orders);
END $$;

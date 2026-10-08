\echo '--- Sample'
SELECT id, orders_count, last_order_at FROM customer ORDER BY id LIMIT 5;

DO $$
DECLARE
    drifted bigint;
BEGIN
    SELECT count(*) INTO drifted
    FROM customer c
    LEFT JOIN (SELECT customer_id, count(*) AS cnt, max(created_at) AS last_at
               FROM orders GROUP BY customer_id) t ON t.customer_id = c.id
    WHERE (c.orders_count, c.last_order_at) IS DISTINCT FROM (coalesce(t.cnt, 0), t.last_at);

    IF drifted > 0 THEN
        RAISE EXCEPTION 'FAIL: % customers have wrong cached values (run demo_reconcile.sql)', drifted;
    END IF;
    RAISE NOTICE 'OK: cached counters match orders for all % customers', (SELECT count(*) FROM customer);
END $$;

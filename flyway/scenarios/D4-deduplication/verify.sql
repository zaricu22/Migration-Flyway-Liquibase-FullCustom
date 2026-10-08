\echo '--- Example: customer 1 after the merge (phone taken from a duplicate)'
SELECT id, email, phone FROM customer WHERE id = 1;

\echo '--- Audit trail'
SELECT * FROM customer_merge_map WHERE survivor_id = 1;

\echo '--- Expected vs actual'
SELECT e.customers AS expected_customers, (SELECT count(*) FROM customer) AS customers,
       e.orders    AS expected_orders,    (SELECT count(*) FROM orders)   AS orders,
       e.wishlist_items AS expected_wishlist, (SELECT count(*) FROM wishlist) AS wishlist
FROM _demo_expected e;

DO $$
DECLARE
    e _demo_expected%ROWTYPE;
BEGIN
    SELECT * INTO e FROM _demo_expected;
    IF (SELECT count(*) FROM customer) <> e.customers THEN
        RAISE EXCEPTION 'FAIL: duplicates left';
    END IF;
    IF (SELECT count(*) FROM orders) <> e.orders OR (SELECT sum(amount) FROM orders) <> e.order_total THEN
        RAISE EXCEPTION 'FAIL: orders lost';
    END IF;
    IF (SELECT count(*) FROM wishlist) <> e.wishlist_items THEN
        RAISE EXCEPTION 'FAIL: wishlist items lost or duplicated';
    END IF;
    RAISE NOTICE 'OK: % customers, all orders and wishlist items kept', e.customers;

    BEGIN
        INSERT INTO customer (email, created_at) VALUES ('USER1@example.com', now());
        RAISE EXCEPTION 'FAIL: duplicate accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'OK: case-insensitive duplicate rejected by the unique index';
    END;
END $$;

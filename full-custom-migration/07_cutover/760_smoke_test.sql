-- CUTOVER step 3 (after the final delta and verify): SMOKE TEST. Verify proved the DATA is right;
-- this checks that the new system answers what the application asks on day one, read AND write.
-- Results go to mig.reconciliation (phase 'cutover'); the go/no-go gate (780) evaluates them.
-- In real life: the application's own smoke tests against the new database, before users come back.
\o /dev/null

-- read path: login lookup, order history, catalog
SELECT mig.check('cutover', 'smoke: login lookup by e-mail finds 1 active customer', 1::bigint,
    (SELECT count(*) FROM public.customer WHERE email = 'user1@example.com' AND active));

SELECT mig.check('cutover', 'smoke: order history of customer 1 has orders with lines', true,
    EXISTS (SELECT 1 FROM public.orders o
            JOIN public.order_line l ON l.order_id = o.id
            JOIN public.customer c   ON c.id = o.customer_id
            WHERE c.legacy_cust_no = 1));

SELECT mig.check('cutover', 'smoke: product lookup by SKU', 1::bigint,
    (SELECT count(*) FROM public.product WHERE sku = 'SKU-0001'));

-- write path: a new order for a migrated customer, then undone. Catches identity columns or
-- sequences that collide with migrated ids, missing defaults, and constraints the app trips over.
DO $$
DECLARE
    v_order bigint;
    v_ok    boolean := false;
BEGIN
    BEGIN
        INSERT INTO public.orders (order_no, customer_id, order_date, status)
        SELECT 'SMOKE-TEST', id, current_date, 'new' FROM public.customer WHERE legacy_cust_no = 1
        RETURNING id INTO v_order;

        INSERT INTO public.order_line (order_id, line_no, product_id, qty, unit_price_cents)
        SELECT v_order, 1, id, 1, price_cents FROM public.product WHERE sku = 'SKU-0001';

        v_ok := v_order IS NOT NULL;
        RAISE EXCEPTION 'undo smoke test';        -- rolls back the inserts (this inner block only)
    EXCEPTION
        WHEN raise_exception THEN NULL;           -- expected: the test order is gone again
        WHEN OTHERS THEN
            RAISE NOTICE 'smoke write failed: %', SQLERRM;
            v_ok := false;
    END;
    PERFORM mig.check('cutover', 'smoke: a new order for a migrated customer can be written (then undone)', true, v_ok);
END $$;

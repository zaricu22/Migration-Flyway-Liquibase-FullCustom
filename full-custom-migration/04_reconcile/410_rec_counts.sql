-- (results go to mig.reconciliation; the gate prints them)
\o /dev/null
-- COUNTS: every source record is accounted for exactly once.
--   customers:   raw = survivors + merged duplicates + rejected
--   products:    raw = staged + rejected
--   orders:      raw = staged + rejected           (distinct order numbers)
--   order lines: raw = staged lines + lines of rejected orders
SELECT mig.check('reconcile', 'customers: raw = survivors + merged + rejected',
    (SELECT count(*) FROM raw.v_customers),
    (SELECT count(*) FROM stg.customer)
    + (SELECT count(*) FROM stg.customer_alias WHERE legacy_cust_no <> survivor_cust_no)
    + (SELECT count(*) FROM mig.v_rejected WHERE entity = 'customer'));

SELECT mig.check('reconcile', 'products: raw = staged + rejected',
    (SELECT count(*) FROM raw.v_products),
    (SELECT count(*) FROM stg.product) + (SELECT count(*) FROM mig.v_rejected WHERE entity = 'product'));

SELECT mig.check('reconcile', 'orders: raw = staged + rejected',
    (SELECT count(DISTINCT order_no) FROM raw.v_order_lines),
    (SELECT count(*) FROM stg.orders) + (SELECT count(*) FROM mig.v_rejected WHERE entity = 'order'));

SELECT mig.check('reconcile', 'order lines: raw = staged + lines of rejected orders',
    (SELECT count(*) FROM raw.v_order_lines),
    (SELECT count(*) FROM stg.order_line)
    + (SELECT count(*) FROM raw.v_order_lines l
       JOIN mig.v_rejected r ON r.entity = 'order' AND r.source_key = l.order_no));

-- nothing in staging that should have been rejected
SELECT mig.check('reconcile', 'no rejected key reached staging', 0::bigint,
    (SELECT count(*) FROM stg.customer_alias a JOIN mig.v_rejected r ON r.entity = 'customer' AND r.source_key = a.legacy_cust_no::text)
    + (SELECT count(*) FROM stg.product p JOIN mig.v_rejected r ON r.entity = 'product' AND r.source_key = p.sku)
    + (SELECT count(*) FROM stg.orders o JOIN mig.v_rejected r ON r.entity = 'order' AND r.source_key = o.order_no));

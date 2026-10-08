-- DEPENDENCIES: a record whose parent is rejected can't be migrated either.
-- (Must run after the other checks: it builds on their REJECTs.)
-- Order atomicity is built in: errors are keyed by order number, so ONE bad line rejects the
-- whole order. A half-migrated order would be worse than a missing one.
INSERT INTO mig.error (run_id, phase, entity, source_key, column_name, raw_value, rule, severity, message)
SELECT DISTINCT mig.current_run(), 'validate', 'order', l.order_no, 'cust_no', l.cust_no, 'customer_rejected', 'REJECT',
       'the order''s customer is rejected'
FROM raw.v_order_lines l
JOIN mig.v_rejected r ON r.entity = 'customer' AND r.source_key = l.cust_no
UNION ALL
SELECT DISTINCT mig.current_run(), 'validate', 'order', l.order_no, 'sku', l.sku, 'product_rejected', 'REJECT',
       'a product on the order is rejected'
FROM raw.v_order_lines l
JOIN mig.v_rejected r ON r.entity = 'product' AND r.source_key = l.sku;

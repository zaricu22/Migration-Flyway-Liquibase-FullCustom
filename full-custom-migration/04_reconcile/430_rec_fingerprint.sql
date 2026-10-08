-- (results go to mig.reconciliation; the gate prints them)
\o /dev/null
-- FINGERPRINTS: an md5 over every relevant value, sorted, on both sides. Catches swapped or altered
-- values that keep counts and totals intact (e.g. two lines exchanging their SKUs).
SELECT mig.check('reconcile', 'order line fingerprint (order, line, sku, qty)',
    (SELECT md5(string_agg(concat_ws('|', l.order_no, l.line_no, l.sku, btrim(l.qty)::int), ','
                           ORDER BY l.order_no, l.line_no::int))
     FROM raw.v_order_lines l
     WHERE NOT EXISTS (SELECT 1 FROM mig.v_rejected r WHERE r.entity = 'order' AND r.source_key = l.order_no)),
    (SELECT md5(string_agg(concat_ws('|', order_no, line_no, sku, qty), ',' ORDER BY order_no, line_no))
     FROM stg.order_line));

-- Customers: the survivors' e-mails must be exactly the distinct e-mails of all accepted records.
SELECT mig.check('reconcile', 'customer e-mail fingerprint (distinct accepted e-mails)',
    (SELECT md5(string_agg(e, ',' ORDER BY e)) FROM (
        SELECT DISTINCT lower(btrim(c.email)) AS e FROM raw.v_customers c
        WHERE NOT EXISTS (SELECT 1 FROM mig.v_rejected r WHERE r.entity = 'customer' AND r.source_key = c.cust_no)) x),
    (SELECT md5(string_agg(email, ',' ORDER BY email)) FROM stg.customer));

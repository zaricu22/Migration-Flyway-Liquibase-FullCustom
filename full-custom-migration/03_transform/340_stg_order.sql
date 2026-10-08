-- Orders: split the denormalized lines into header + lines, map status codes, point every order
-- to the SURVIVOR customer (orders of merged duplicates move with them).
-- Header consistency was validated, so any line's copy of the header is the same.
INSERT INTO stg.orders (order_no, legacy_cust_no, order_date, status)
SELECT DISTINCT ON (l.order_no)
       l.order_no,
       a.survivor_cust_no,
       mig.parse_date(l.order_date),
       m.new_code
FROM raw.v_order_lines l
JOIN stg.customer_alias a ON a.legacy_cust_no = l.cust_no::int
JOIN mig.code_map m ON m.entity = 'order_status' AND m.old_code = lower(btrim(l.status_code))
WHERE NOT EXISTS (SELECT 1 FROM mig.v_rejected r WHERE r.entity = 'order' AND r.source_key = l.order_no)
ORDER BY l.order_no, l.line_no;

INSERT INTO stg.order_line (order_no, line_no, sku, qty, unit_price_cents)
SELECT l.order_no, l.line_no::int, l.sku, btrim(l.qty)::int, mig.parse_amount_cents(l.unit_price)
FROM raw.v_order_lines l
JOIN stg.orders o ON o.order_no = l.order_no;

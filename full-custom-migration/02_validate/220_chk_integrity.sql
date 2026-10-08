-- INTEGRITY: do the references hold, and is the denormalized data consistent?
INSERT INTO mig.error (run_id, phase, entity, source_key, column_name, raw_value, rule, severity, message)
-- order points to a customer that doesn't exist in the source
SELECT DISTINCT mig.current_run(), 'validate', 'order', l.order_no, 'cust_no', l.cust_no, 'orphan_customer', 'REJECT',
       'customer does not exist in the source'
FROM raw.v_order_lines l
WHERE NOT EXISTS (SELECT 1 FROM raw.v_customers c WHERE c.cust_no = l.cust_no)
UNION ALL
-- line points to a product that doesn't exist in the source
SELECT mig.current_run(), 'validate', 'order', l.order_no, 'sku', l.sku, 'orphan_product', 'REJECT',
       'line ' || l.line_no || ': product does not exist in the source'
FROM raw.v_order_lines l
WHERE NOT EXISTS (SELECT 1 FROM raw.v_products p WHERE p.sku = l.sku)
UNION ALL
-- the order header is repeated on every line: all copies must agree, otherwise
-- "one order row" is ambiguous (which date / customer / status is right?)
SELECT mig.current_run(), 'validate', 'order', order_no, 'header', NULL, 'inconsistent_header', 'REJECT',
       count(DISTINCT (cust_no, order_date, status_code)) || ' different header versions across the lines'
FROM raw.v_order_lines
GROUP BY order_no
HAVING count(DISTINCT (cust_no, order_date, status_code)) > 1;

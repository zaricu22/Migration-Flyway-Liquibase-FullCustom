-- BUSINESS RULES: the value is parseable, but is it allowed / mappable?
INSERT INTO mig.error (run_id, phase, entity, source_key, column_name, raw_value, rule, severity, message)
SELECT mig.current_run(), 'validate', 'customer', cust_no, 'country', country, 'unmapped_country', 'REJECT',
       'country has no entry in mig.code_map'
FROM raw.v_customers c
WHERE NOT EXISTS (SELECT 1 FROM mig.code_map m
                  WHERE m.entity = 'country' AND m.old_code = lower(btrim(c.country)))
UNION ALL
SELECT mig.current_run(), 'validate', 'product', sku, 'price', price, 'price_not_positive', 'REJECT',
       'price must be greater than 0'
FROM raw.v_products
WHERE mig.parse_amount_cents(price) <= 0
UNION ALL
SELECT DISTINCT mig.current_run(), 'validate', 'order', l.order_no, 'status_code', l.status_code, 'unmapped_status', 'REJECT',
       'status code has no entry in mig.code_map'
FROM raw.v_order_lines l
WHERE NOT EXISTS (SELECT 1 FROM mig.code_map m
                  WHERE m.entity = 'order_status' AND m.old_code = lower(btrim(l.status_code)))
UNION ALL
SELECT mig.current_run(), 'validate', 'order', order_no, 'qty', qty, 'qty_not_positive', 'REJECT',
       'line ' || line_no || ': quantity must be greater than 0'
FROM raw.v_order_lines
WHERE btrim(qty) ~ '^\d+$' AND btrim(qty)::int <= 0;

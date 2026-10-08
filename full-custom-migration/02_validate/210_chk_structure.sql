-- STRUCTURE: is each value parseable into the target type / format?
-- Reads raw only, writes mig.error only. Same parse functions as the transformation (003_helpers).
INSERT INTO mig.error (run_id, phase, entity, source_key, column_name, raw_value, rule, severity, message)
-- customers
SELECT mig.current_run(), 'validate', 'customer', cust_no, 'email', email, 'email_format', 'REJECT',
       'not a valid e-mail address'
FROM raw.v_customers
WHERE email IS NULL OR mig.normalize_email(email) !~ '^[^@\s]+@[^@\s]+\.[a-z]{2,}$'
UNION ALL
SELECT mig.current_run(), 'validate', 'customer', cust_no, 'created', created, 'date_format', 'REJECT',
       'not a valid date (DD.MM.YYYY or YYYY-MM-DD)'
FROM raw.v_customers
WHERE mig.parse_date(created) IS NULL
UNION ALL
SELECT mig.current_run(), 'validate', 'customer', cust_no, 'phone', phone, 'phone_format', 'WARN',
       'phone cannot be converted to E.164, migrated without phone'
FROM raw.v_customers
WHERE phone IS NOT NULL AND mig.normalize_phone(phone) IS NULL
UNION ALL
SELECT mig.current_run(), 'validate', 'customer', cust_no, 'address', address, 'address_format', 'WARN',
       'address cannot be parsed, migrated without address'
FROM raw.v_customers
WHERE address IS NOT NULL AND mig.parse_address(address) IS NULL
-- products
UNION ALL
SELECT mig.current_run(), 'validate', 'product', sku, 'price', price, 'amount_format', 'REJECT',
       'price is not a number'
FROM raw.v_products
WHERE mig.parse_amount_cents(price) IS NULL
-- orders (one order = all its lines; the key is the order number)
UNION ALL
SELECT mig.current_run(), 'validate', 'order', order_no, 'qty', qty, 'qty_format', 'REJECT',
       'line ' || line_no || ': quantity is not an integer'
FROM raw.v_order_lines
WHERE btrim(qty) !~ '^\d+$'
UNION ALL
SELECT mig.current_run(), 'validate', 'order', order_no, 'order_date', order_date, 'date_format', 'REJECT',
       'line ' || line_no || ': not a valid date'
FROM raw.v_order_lines
WHERE mig.parse_date(order_date) IS NULL
UNION ALL
SELECT mig.current_run(), 'validate', 'order', order_no, 'unit_price', unit_price, 'amount_format', 'REJECT',
       'line ' || line_no || ': unit price is not a number'
FROM raw.v_order_lines
WHERE mig.parse_amount_cents(unit_price) IS NULL;

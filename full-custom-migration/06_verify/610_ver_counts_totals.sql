-- (results go to mig.reconciliation; the gate prints them)
\o /dev/null
-- Did staging arrive in production COMPLETELY and UNCHANGED?
-- "stg EXCEPT target" compares every column: 0 rows = every staged row exists in production with
-- exactly these values. (Production may contain more: rows from earlier runs, or created by users.)
SELECT mig.check('verify', 'customers: staged rows missing/different in target', 0::bigint,
    (SELECT count(*) FROM (
        SELECT legacy_cust_no, email, first_name, last_name, phone, country_code, created_on, active FROM stg.customer
        EXCEPT
        SELECT legacy_cust_no, email, first_name, last_name, phone, country_code, created_on, active FROM public.customer) d));

SELECT mig.check('verify', 'addresses: staged rows missing/different in target', 0::bigint,
    (SELECT count(*) FROM (
        SELECT legacy_cust_no, street, zip, city FROM stg.address
        EXCEPT
        SELECT c.legacy_cust_no, a.street, a.zip, a.city
        FROM public.address a JOIN public.customer c ON c.id = a.customer_id) d));

SELECT mig.check('verify', 'products: staged rows missing/different in target', 0::bigint,
    (SELECT count(*) FROM (
        SELECT sku, title, category_name, price_cents FROM stg.product
        EXCEPT
        SELECT p.sku, p.title, c.name, p.price_cents
        FROM public.product p JOIN public.category c ON c.id = p.category_id) d));

SELECT mig.check('verify', 'orders: staged rows missing/different in target', 0::bigint,
    (SELECT count(*) FROM (
        SELECT order_no, legacy_cust_no, order_date, status FROM stg.orders
        EXCEPT
        SELECT o.order_no, c.legacy_cust_no, o.order_date, o.status
        FROM public.orders o JOIN public.customer c ON c.id = o.customer_id) d));

SELECT mig.check('verify', 'order lines: staged rows missing/different in target', 0::bigint,
    (SELECT count(*) FROM (
        SELECT order_no, line_no, sku, qty, unit_price_cents FROM stg.order_line
        EXCEPT
        SELECT o.order_no, l.line_no, p.sku, l.qty, l.unit_price_cents
        FROM public.order_line l
        JOIN public.orders o  ON o.id = l.order_id
        JOIN public.product p ON p.id = l.product_id) d));

SELECT mig.check('verify', 'order amount total (cents): staged = target',
    (SELECT sum(qty * unit_price_cents) FROM stg.order_line),
    (SELECT sum(l.qty * l.unit_price_cents) FROM public.order_line l
     JOIN public.orders o ON o.id = l.order_id
     WHERE o.order_no IN (SELECT order_no FROM stg.orders)));

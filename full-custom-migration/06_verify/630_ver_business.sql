-- (results go to mig.reconciliation; the gate prints them)
\o /dev/null
-- Business spot checks: records whose correct outcome is KNOWN in advance (in a real project:
-- a list agreed with the business, e.g. "our 20 biggest customers and their open orders").
-- Every rule of the migration should have at least one such check.

-- straightforward record, every field converted
SELECT mig.check('verify', 'legacy customer 1: e-mail, name, phone, country, date',
    'user1@example.com|First1|Last1|+381640000001|RS|2019-01-02',
    (SELECT concat_ws('|', email, first_name, last_name, phone, country_code, created_on)
     FROM public.customer WHERE legacy_cust_no = 1));

-- deduplication: 1901 (USER1@EXAMPLE.COM) was merged into customer 1
SELECT mig.check('verify', 'duplicate 1901 merged into customer 1',
    (SELECT new_id FROM mig.id_map WHERE entity = 'customer' AND legacy_key = '1'),
    (SELECT new_id FROM mig.id_map WHERE entity = 'customer' AND legacy_key = '1901'));

-- one-word name: first name only
SELECT mig.check('verify', 'legacy customer 97: one-word name -> first name only', 'Mononym97|',
    (SELECT first_name || '|' || coalesce(last_name, '') FROM public.customer WHERE legacy_cust_no = 97));

-- WARN, not REJECT: unparseable address -> customer migrated without address
SELECT mig.check('verify', 'legacy customer 50: migrated, without address', 'customer|no address',
    (SELECT 'customer|' || CASE WHEN a.customer_id IS NULL THEN 'no address' ELSE 'address' END
     FROM public.customer c LEFT JOIN public.address a ON a.customer_id = c.id
     WHERE c.legacy_cust_no = 50));

-- rejected: invalid e-mail -> customer AND its orders are not in production
SELECT mig.check('verify', 'legacy customer 500 (e-mail without @) not migrated', 0::bigint,
    (SELECT count(*) FROM public.customer WHERE legacy_cust_no = 500));

-- order atomicity: ORD-000500 had one line with qty 0 -> the whole order is rejected
SELECT mig.check('verify', 'ORD-000500 (one line with qty 0) not migrated', 0::bigint,
    (SELECT count(*) FROM public.orders WHERE order_no = 'ORD-000500'));

-- code mapping: status 'P' -> 'paid', 'PEND' -> 'new'
SELECT mig.check('verify', 'status mapping: ORD-000001 P -> paid, ORD-000004 PEND -> new', 'paid|new',
    (SELECT (SELECT status FROM public.orders WHERE order_no = 'ORD-000001') || '|' ||
            (SELECT status FROM public.orders WHERE order_no = 'ORD-000004')));

-- price with decimal comma: SKU-0002 '3,02' -> 302 cents
SELECT mig.check('verify', 'SKU-0002 price 3,02 -> 302 cents', 302::bigint,
    (SELECT price_cents FROM public.product WHERE sku = 'SKU-0002'));

-- category spelled 7 ways -> 3 categories
SELECT mig.check('verify', 'categories normalized to 3', 3::bigint,
    (SELECT count(*) FROM public.category));

-- Extra expectations after a DELTA run (./run.sh delta applies source/legacy_changes.sql)
SELECT mig.check('verify', 'delta: e-mail change of customer 150 arrived', 'new.user150@example.com',
    (SELECT email FROM public.customer WHERE legacy_cust_no = 150))
WHERE (SELECT kind FROM mig.run WHERE run_id = mig.current_run()) = 'delta';

SELECT mig.check('verify', 'delta: fixed customer 250 + its orders now migrated', true,
    EXISTS (SELECT 1 FROM public.customer WHERE legacy_cust_no = 250)
    AND EXISTS (SELECT 1 FROM public.orders o JOIN public.customer c ON c.id = o.customer_id WHERE c.legacy_cust_no = 250))
WHERE (SELECT kind FROM mig.run WHERE run_id = mig.current_run()) = 'delta';

SELECT mig.check('verify', 'delta: new customer 2001 + ORD-006001, ORD-000010 shipped', 'shipped|2',
    (SELECT (SELECT status FROM public.orders WHERE order_no = 'ORD-000010') || '|' ||
            (SELECT count(*) FROM public.order_line l JOIN public.orders o ON o.id = l.order_id
             JOIN public.customer c ON c.id = o.customer_id
             WHERE o.order_no = 'ORD-006001' AND c.legacy_cust_no = 2001)))
WHERE (SELECT kind FROM mig.run WHERE run_id = mig.current_run()) = 'delta';

-- deletes in the old system (detected by the full key comparison of the delta)
SELECT mig.check('verify', 'delta: ORD-000020 deleted, ORD-000011 line 4 deleted', '0|3',
    (SELECT (SELECT count(*) FROM public.orders WHERE order_no = 'ORD-000020') || '|' ||
            (SELECT count(*) FROM public.order_line l JOIN public.orders o ON o.id = l.order_id
             WHERE o.order_no = 'ORD-000011')))
WHERE (SELECT kind FROM mig.run WHERE run_id = mig.current_run()) = 'delta';

SELECT mig.check('verify', 'delta: customer 301 deleted in source -> deactivated, its orders removed', 'false|0',
    (SELECT (SELECT active::text FROM public.customer WHERE legacy_cust_no = 301) || '|' ||
            (SELECT count(*) FROM public.orders o JOIN public.customer c ON c.id = o.customer_id
             WHERE c.legacy_cust_no = 301)))
WHERE (SELECT kind FROM mig.run WHERE run_id = mig.current_run()) = 'delta';

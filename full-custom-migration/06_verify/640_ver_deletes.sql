-- (results go to mig.reconciliation; the gate prints them)
\o /dev/null
-- Did every deletion in the source arrive in production, as the rules of 05_load/560 say?
-- (All 0 after a full run: deletes are found only by a delta.)
SELECT mig.check('verify', 'deletes: order lines deleted in source still in production', 0::bigint,
    (SELECT count(*) FROM public.order_line l
     JOIN public.orders o ON o.id = l.order_id
     JOIN raw.v_deleted_order_lines d ON d.order_no = o.order_no AND d.line_no::int = l.line_no));

SELECT mig.check('verify', 'deletes: orders without any source line still in production', 0::bigint,
    (SELECT count(*) FROM public.orders o
     WHERE EXISTS (SELECT 1 FROM raw.v_deleted_order_lines d WHERE d.order_no = o.order_no)
       AND NOT EXISTS (SELECT 1 FROM raw.v_order_lines v WHERE v.order_no = o.order_no)));

SELECT mig.check('verify', 'deletes: customers deleted in source still active in production', 0::bigint,
    (SELECT count(*) FROM public.customer c
     JOIN raw.v_deleted_customers d ON c.legacy_cust_no = d.cust_no::int
     WHERE c.active));

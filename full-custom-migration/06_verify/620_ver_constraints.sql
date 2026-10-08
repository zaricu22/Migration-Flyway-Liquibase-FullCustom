-- (results go to mig.reconciliation; the gate prints them)
\o /dev/null
-- Structural health of production after the load.
SELECT mig.check('verify', 'all target constraints validated', 0::bigint,
    (SELECT count(*) FROM pg_constraint
     WHERE connamespace = 'public'::regnamespace AND NOT convalidated));

SELECT mig.check('verify', 'orders without lines', 0::bigint,
    (SELECT count(*) FROM public.orders o
     WHERE NOT EXISTS (SELECT 1 FROM public.order_line l WHERE l.order_id = o.id)));

SELECT mig.check('verify', 'id map complete: every staged customer alias mapped', 0::bigint,
    (SELECT count(*) FROM stg.customer_alias a
     WHERE NOT EXISTS (SELECT 1 FROM mig.id_map m WHERE m.entity = 'customer' AND m.legacy_key = a.legacy_cust_no::text)));

SELECT mig.check('verify', 'id map points to existing rows', 0::bigint,
    (SELECT count(*) FROM mig.id_map m
     WHERE (m.entity = 'customer' AND NOT EXISTS (SELECT 1 FROM public.customer t WHERE t.id = m.new_id))
        OR (m.entity = 'product'  AND NOT EXISTS (SELECT 1 FROM public.product  t WHERE t.id = m.new_id))
        OR (m.entity = 'order'    AND NOT EXISTS (SELECT 1 FROM public.orders   t WHERE t.id = m.new_id))));

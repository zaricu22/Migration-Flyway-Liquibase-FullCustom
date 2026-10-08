-- ROLLBACK: remove everything the migration inserted into production, and nothing else.
-- mig.id_map knows exactly which rows those are. Children first (FK order), one transaction.
--
-- Prepared and TESTED before go-live, but only safe until users start writing to the new system:
-- after that, new rows reference migrated ones and a rollback would destroy real work
-- (then the only way is forward: fix the data, don't remove it).
DELETE FROM public.order_line l
USING mig.id_map m
WHERE m.entity = 'order' AND l.order_id = m.new_id;

DELETE FROM public.orders o
USING mig.id_map m
WHERE m.entity = 'order' AND o.id = m.new_id;

DELETE FROM public.customer c                              -- addresses go with ON DELETE CASCADE
WHERE c.id IN (SELECT new_id FROM mig.id_map WHERE entity = 'customer');

DELETE FROM public.product p
USING mig.id_map m
WHERE m.entity = 'product' AND p.id = m.new_id;

DELETE FROM public.category c
USING mig.id_map m
WHERE m.entity = 'category' AND c.id = m.new_id;

DELETE FROM mig.id_map;
DELETE FROM mig.checkpoint;
UPDATE mig.run SET status = 'ROLLED_BACK', finished_at = coalesce(finished_at, clock_timestamp())
WHERE status <> 'ROLLED_BACK';

\echo 'Target after the rollback:'
SELECT 'customer' AS target_table, count(*) AS rows FROM public.customer
UNION ALL SELECT 'product', count(*) FROM public.product
UNION ALL SELECT 'orders', count(*) FROM public.orders
UNION ALL SELECT 'order_line', count(*) FROM public.order_line;

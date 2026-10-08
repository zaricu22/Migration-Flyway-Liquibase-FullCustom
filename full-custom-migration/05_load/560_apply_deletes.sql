-- DELETES from the source (tombstones found by 07_cutover/710_delta_sync.sql). The upserts above only
-- insert and update; this step decides what a deletion in the old system means in the new one.
-- Only rows the MIGRATION created (listed in mig.id_map) are touched, never rows created by users.
--
-- The rules here are business decisions, and they differ per entity:
--   order lines  deleted -> deleted in production
--   orders       all lines deleted -> order deleted (its lines go with ON DELETE CASCADE)
--   customers    deleted -> DEACTIVATED, not deleted: production keeps their order history
--                (for a GDPR erasure request: anonymize the personal columns instead)
--   products     deleted -> kept: historic order lines still reference them; reported only

-- order lines
DELETE FROM public.order_line l
USING public.orders o, raw.v_deleted_order_lines d, mig.id_map m
WHERE o.id = l.order_id
  AND d.order_no = o.order_no AND d.line_no::int = l.line_no
  AND m.entity = 'order' AND m.new_id = o.id;

-- orders that have no live line left in the source
CREATE TEMP TABLE deleted_orders ON COMMIT DROP AS
SELECT o.id, o.order_no
FROM public.orders o
JOIN mig.id_map m ON m.entity = 'order' AND m.new_id = o.id
WHERE EXISTS (SELECT 1 FROM raw.v_deleted_order_lines d WHERE d.order_no = o.order_no)
  AND NOT EXISTS (SELECT 1 FROM raw.v_order_lines v WHERE v.order_no = o.order_no);

DELETE FROM public.orders o USING deleted_orders d WHERE o.id = d.id;
DELETE FROM mig.id_map m USING deleted_orders d WHERE m.entity = 'order' AND m.legacy_key = d.order_no;

-- customers: only the production row that belongs to this legacy number (a deleted merged
-- duplicate does not deactivate its survivor)
UPDATE public.customer c
SET active = false
FROM raw.v_deleted_customers d
WHERE c.legacy_cust_no = d.cust_no::int
  AND c.active
  AND EXISTS (SELECT 1 FROM mig.id_map m WHERE m.entity = 'customer' AND m.new_id = c.id);

\echo 'Deletes from the source applied in this run:'
SELECT 'orders deleted' AS action, count(*) AS rows FROM deleted_orders
UNION ALL
SELECT 'customers deactivated (deleted in source, total)', count(*)
FROM public.customer c JOIN raw.v_deleted_customers d ON c.legacy_cust_no = d.cust_no::int
UNION ALL
SELECT 'products deleted in source (kept in production)', count(*) FROM raw.v_deleted_products;

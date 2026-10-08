-- Convert the old rows. The conditional rule ('X' + refunded_at -> 'refunded') can't be
-- expressed in a 1:1 mapping table, so it's an explicit CASE on top of the join.
-- (Batch on large tables, see D2.)
UPDATE orders o
SET status = CASE
                 WHEN o.status = 'X' AND o.refunded_at IS NOT NULL THEN 'refunded'
                 ELSE m.new_code
             END
FROM status_mapping m
WHERE m.old_code = o.status;

ALTER TABLE orders VALIDATE CONSTRAINT orders_status_valid;

-- >>> Deploy app v2 (writes new codes) before V4. <<<

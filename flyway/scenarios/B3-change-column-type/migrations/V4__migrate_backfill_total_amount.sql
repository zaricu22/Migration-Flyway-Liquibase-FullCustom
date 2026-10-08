-- MIGRATE: convert existing values. round(), not a plain cast: 0.30000000000000004 must become 0.30.
-- (Batch this on big tables, see D2.)
UPDATE orders SET total_amount = round(amount::numeric, 2) WHERE total_amount IS NULL;

ALTER TABLE orders ALTER COLUMN total_amount SET NOT NULL;

-- >>> Deploy app v2 (reads/writes total_amount only) before V5. <<<

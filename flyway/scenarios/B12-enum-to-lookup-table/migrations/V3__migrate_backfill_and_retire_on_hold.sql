-- MIGRATE: fill the code column, then retire 'on_hold'. Small table -> single statements.
-- On a large table, backfill in batches (D2) and use the safe NOT NULL pattern (B4).
UPDATE orders SET status_code = status::text WHERE status_code IS NULL;

-- The business decision: 'on_hold' orders go back to 'new' (the trigger keeps both columns in sync).
UPDATE orders SET status_code = 'new' WHERE status_code = 'on_hold';

-- Removing the value is now a plain DELETE. The FK blocks it while any row still uses it.
-- From here on, writing 'on_hold' fails with an FK violation, even from app v1 (via the trigger).
DELETE FROM order_status_code WHERE code = 'on_hold';

ALTER TABLE orders VALIDATE CONSTRAINT orders_status_code_fk;
ALTER TABLE orders ALTER COLUMN status_code SET NOT NULL;
-- No DEFAULT on status_code yet: the trigger would take a defaulted code for "app v2 wrote it"
-- and overwrite the enum value app v1 inserted. The default moves over in V4.

-- >>> Deploy app v2 (uses only status_code) and retire all app v1 instances before V4. <<<

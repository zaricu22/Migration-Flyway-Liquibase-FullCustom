-- CONTRACT: nobody uses the enum column anymore. Remove the sync machinery, the column and the type.
SET LOCAL lock_timeout = '5s';

DROP TRIGGER orders_sync_status ON orders;
DROP FUNCTION orders_sync_status();
ALTER TABLE orders DROP COLUMN status;
ALTER TABLE orders ALTER COLUMN status_code SET DEFAULT 'new';
DROP TYPE order_status;       -- fails if anything still uses it (no CASCADE, see B10)

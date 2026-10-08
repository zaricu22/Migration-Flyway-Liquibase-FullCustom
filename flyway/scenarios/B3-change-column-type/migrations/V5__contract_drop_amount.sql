SET LOCAL lock_timeout = '5s';

DROP TRIGGER orders_sync_amount ON orders;
DROP FUNCTION orders_sync_amount();
ALTER TABLE orders DROP COLUMN amount;

INSERT INTO _demo_filenode VALUES ('3 after V5 (expand/contract)', pg_relation_filenode('orders'));

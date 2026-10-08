SET LOCAL lock_timeout = '5s';

DROP TRIGGER customer_sync_name ON customer;
DROP FUNCTION customer_sync_name();
DROP FUNCTION name_first(text);
DROP FUNCTION name_last(text);
ALTER TABLE customer DROP COLUMN full_name;
-- Readers that still want a display name can compute it (or use a view / generated column):
--   concat_ws(' ', first_name, last_name)

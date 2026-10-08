-- Full scans, but under SHARE UPDATE EXCLUSIVE: traffic continues.
-- Validated now (slow, but not blocking), so column swaping in V7 is FAST:
--  SET NOT NULL skips its scan and the FK is already valid.
--  V7 then holds its exclusive locks for milliseconds, not for scans.
ALTER TABLE customer VALIDATE CONSTRAINT customer_id_new_not_null;
ALTER TABLE orders   VALIDATE CONSTRAINT orders_customer_id_new_not_null;
ALTER TABLE orders   VALIDATE CONSTRAINT orders_customer_id_new_fk;

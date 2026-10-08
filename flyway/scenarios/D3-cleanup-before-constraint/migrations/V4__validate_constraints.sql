-- Step 3: prove the old rows are clean. Scans run under SHARE UPDATE EXCLUSIVE (traffic continues).
ALTER TABLE orders   VALIDATE CONSTRAINT orders_customer_id_fk;
ALTER TABLE orders   VALIDATE CONSTRAINT orders_quantity_positive;
ALTER TABLE orders   VALIDATE CONSTRAINT orders_status_valid;
ALTER TABLE customer VALIDATE CONSTRAINT customer_email_not_null;

-- Turn the helper CHECK into a real NOT NULL (no scan thanks to the validated CHECK, see B4).
ALTER TABLE customer ALTER COLUMN email SET NOT NULL;
ALTER TABLE customer DROP CONSTRAINT customer_email_not_null;

-- VALIDATE scans the existing rows, but only takes a SHARE UPDATE EXCLUSIVE lock on orders:
-- reads and writes continue during the scan. (The FK takes a ROW SHARE lock on customer.)
-- This must be a separate migration (= separate transaction). Validating in the same
-- transaction as the ADD would keep ADD's stronger lock for the entire scan.
ALTER TABLE orders VALIDATE CONSTRAINT orders_customer_id_fk;
ALTER TABLE orders VALIDATE CONSTRAINT orders_amount_positive;

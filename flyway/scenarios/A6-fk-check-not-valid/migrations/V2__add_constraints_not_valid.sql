-- NOT VALID: the constraint is enforced immediately for every NEW insert/update,
-- but existing rows are not scanned. Only a brief lock is needed, no full table scan.
SET LOCAL lock_timeout = '5s';

ALTER TABLE orders
    ADD CONSTRAINT orders_customer_id_fk FOREIGN KEY (customer_id) REFERENCES customer (id) NOT VALID;

ALTER TABLE orders
    ADD CONSTRAINT orders_amount_positive CHECK (amount > 0) NOT VALID;

-- Step 1: constraints FIRST, as NOT VALID.
-- Existing bad rows are tolerated for now, but no NEW bad rows can be written from this moment.
-- Cleaning first and constraining later leaves a window in which the app can insert fresh
-- garbage, and then VALIDATE fails anyway.
SET LOCAL lock_timeout = '5s';

ALTER TABLE orders ADD CONSTRAINT orders_customer_id_fk
    FOREIGN KEY (customer_id) REFERENCES customer (id) NOT VALID;

ALTER TABLE orders ADD CONSTRAINT orders_quantity_positive
    CHECK (quantity > 0) NOT VALID;

ALTER TABLE orders ADD CONSTRAINT orders_status_valid
    CHECK (status IN ('new', 'paid', 'shipped', 'cancelled', 'on_hold')) NOT VALID;

ALTER TABLE customer ADD CONSTRAINT customer_email_not_null
    CHECK (email IS NOT NULL) NOT VALID;

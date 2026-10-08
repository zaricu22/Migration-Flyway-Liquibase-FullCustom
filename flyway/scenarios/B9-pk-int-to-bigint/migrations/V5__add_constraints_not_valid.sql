-- Constraints for the new columns, NOT VALID = no scan now (see A6, B4).
--   * CHECK (... IS NOT NULL): lets SET NOT NULL in V7 skip its table scan
--   * the new FK references the unique index on customer.id_new
SET LOCAL lock_timeout = '5s';

ALTER TABLE customer
    ADD CONSTRAINT customer_id_new_not_null CHECK (id_new IS NOT NULL) NOT VALID;

ALTER TABLE orders
    ADD CONSTRAINT orders_customer_id_new_not_null CHECK (customer_id_new IS NOT NULL) NOT VALID;

ALTER TABLE orders
    ADD CONSTRAINT orders_customer_id_new_fk FOREIGN KEY (customer_id_new) REFERENCES customer (id_new) NOT VALID;

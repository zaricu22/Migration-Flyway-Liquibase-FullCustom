-- The future PK index and the future FK index, built without blocking writes (see A4).
-- CONCURRENTLY is the standard non-blocking way to build indexes.
DROP INDEX CONCURRENTLY IF EXISTS customer_id_new_uq;
CREATE UNIQUE INDEX CONCURRENTLY customer_id_new_uq ON customer (id_new);

DROP INDEX CONCURRENTLY IF EXISTS orders_customer_id_new_idx;
CREATE INDEX CONCURRENTLY orders_customer_id_new_idx ON orders (customer_id_new);

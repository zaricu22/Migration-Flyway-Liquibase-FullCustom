DROP INDEX CONCURRENTLY IF EXISTS customer_public_id_uq;
CREATE UNIQUE INDEX CONCURRENTLY customer_public_id_uq ON customer (public_id);

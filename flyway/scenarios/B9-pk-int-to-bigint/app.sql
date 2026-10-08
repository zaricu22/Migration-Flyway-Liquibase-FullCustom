-- The application. The SAME queries work before, during and after the migration:
-- column names never change, only their type does.
\echo '--- app: new customer + order'
WITH c AS (
    INSERT INTO customer (email) VALUES ('app-' || floor(random() * 1e6) || '@example.com') RETURNING id
)
INSERT INTO orders (customer_id, amount) SELECT id, 42.00 FROM c RETURNING id, customer_id;

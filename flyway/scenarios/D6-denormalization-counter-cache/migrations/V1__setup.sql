-- The customer list page shows "number of orders" and "last order" per customer, computed with
-- count(*)/max() over orders on every request. Goal: store them on customer (counter cache).
CREATE TABLE customer (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email varchar(255) NOT NULL
);

CREATE TABLE orders (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id bigint      NOT NULL REFERENCES customer (id),
    created_at  timestamptz NOT NULL
);
CREATE INDEX orders_customer_id_idx ON orders (customer_id);

INSERT INTO customer (email)
SELECT 'user' || g || '@example.com' FROM generate_series(1, 5000) AS g;

INSERT INTO orders (customer_id, created_at)
SELECT 1 + (random() * 4999)::int, now() - (random() * 1000 || ' days')::interval
FROM generate_series(1, 200000) AS g;

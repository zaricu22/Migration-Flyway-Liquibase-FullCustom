CREATE TABLE customer (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email varchar(255) NOT NULL
);

-- orders was created without any constraints ("we'll add them later").
CREATE TABLE orders (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id bigint        NOT NULL,
    amount      numeric(12,2) NOT NULL
);

INSERT INTO customer (email)
SELECT 'user' || g || '@example.com' FROM generate_series(1, 10000) AS g;

INSERT INTO orders (customer_id, amount)
SELECT 1 + (g % 10000), round((random() * 500 + 1)::numeric, 2)
FROM generate_series(1, 300000) AS g;

CREATE INDEX orders_customer_id_idx ON orders (customer_id);

-- 1:1 today: customer_id is the primary key of address -> max one address per customer.
-- Goal: many addresses per customer, exactly one of them primary.
CREATE TABLE customer (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email varchar(255) NOT NULL
);

CREATE TABLE address (
    customer_id bigint PRIMARY KEY REFERENCES customer (id) ON DELETE CASCADE,
    street      varchar(200) NOT NULL,
    city        varchar(100) NOT NULL
);

INSERT INTO customer (email)
SELECT 'user' || g || '@example.com' FROM generate_series(1, 10000) AS g;

INSERT INTO address (customer_id, street, city)
SELECT id, id || ' Main Street', (ARRAY['Belgrade', 'Berlin', 'Paris'])[1 + id % 3]
FROM customer WHERE id % 10 <> 0;

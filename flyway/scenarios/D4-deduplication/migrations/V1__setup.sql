-- Duplicate customers: the same person signed up several times with different email casing.
-- Goal: one customer per email (case-insensitive) + a unique index that keeps it that way.
CREATE TABLE customer (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email      varchar(255) NOT NULL,
    phone      varchar(32),
    created_at timestamptz  NOT NULL
);

CREATE TABLE orders (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id bigint NOT NULL REFERENCES customer (id),     -- no CASCADE: safety net (see V2)
    amount      numeric(12,2) NOT NULL
);

CREATE TABLE wishlist (
    customer_id bigint NOT NULL REFERENCES customer (id),
    product_id  bigint NOT NULL,
    PRIMARY KEY (customer_id, product_id)
);

-- 5,000 originals
INSERT INTO customer (email, phone, created_at)
SELECT 'user' || g || '@example.com', NULL, now() - interval '2 years' + (g || ' minutes')::interval
FROM generate_series(1, 5000) AS g;

-- 600 duplicates of the first 300 customers (two each), created later, some WITH a phone number
INSERT INTO customer (email, phone, created_at)
SELECT CASE WHEN d = 1 THEN 'User' || g || '@Example.com' ELSE ' USER' || g || '@EXAMPLE.COM ' END,
       CASE WHEN d = 2 THEN '+3816' || lpad(g::text, 7, '0') END,
       now() - interval '1 year' + (g || ' minutes')::interval
FROM generate_series(1, 300) AS g, generate_series(1, 2) AS d;

-- orders spread over originals and duplicates
INSERT INTO orders (customer_id, amount)
SELECT 1 + g % 5600, 10 + g % 90 FROM generate_series(1, 20000) AS g;

-- wishlists: originals AND their duplicates like the same products -> conflicts when merging
INSERT INTO wishlist (customer_id, product_id)
SELECT c.id, p FROM customer c, generate_series(1, 3) AS p;

-- Expected results, computed up front for verify.sql
CREATE TABLE _demo_expected AS
SELECT (SELECT count(DISTINCT lower(trim(email))) FROM customer) AS customers,
       (SELECT count(*) FROM orders)                             AS orders,
       (SELECT sum(amount) FROM orders)                          AS order_total,
       (SELECT count(DISTINCT (lower(trim(c.email)), w.product_id))
        FROM wishlist w JOIN customer c ON c.id = w.customer_id) AS wishlist_items;

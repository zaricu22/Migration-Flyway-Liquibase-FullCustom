-- Years of "the app validates it": no constraints in the database, and the data shows it.
CREATE TABLE customer (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email varchar(255)                       -- should be NOT NULL
);

CREATE TABLE orders (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id bigint      NOT NULL,        -- should be a FK
    quantity    int         NOT NULL,        -- should be > 0
    status      varchar(20) NOT NULL         -- should be one of new/paid/shipped/cancelled
);

INSERT INTO customer (email)
SELECT CASE WHEN g % 100 = 0 THEN NULL ELSE 'user' || g || '@example.com' END      -- 30 NULL emails
FROM generate_series(1, 3000) AS g;

INSERT INTO orders (customer_id, quantity, status)
SELECT CASE WHEN g % 1000 = 0 THEN 900000 + g ELSE 1 + g % 3000 END,              -- 50 orphans
       CASE WHEN g % 1250 = 0 THEN -2 WHEN g % 5000 = 1 THEN 0 ELSE 1 + g % 5 END, -- negatives + zeros
       CASE g % 400 WHEN 0 THEN 'PAID' WHEN 1 THEN ' Shipped ' WHEN 2 THEN 'shiped' WHEN 3 THEN '???'
            ELSE (ARRAY['new', 'paid', 'shipped', 'cancelled'])[1 + g % 4] END   -- dirty statuses
FROM generate_series(1, 50000) AS g;

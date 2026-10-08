-- Two things are obsolete: the column customer.legacy_code and the table customer_legacy_login.
-- Both still have dependents: a view uses the column, and the table has a FK to customer.
CREATE TABLE customer (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       varchar(255) NOT NULL,
    legacy_code varchar(20)
);

CREATE TABLE customer_legacy_login (
    customer_id bigint PRIMARY KEY REFERENCES customer (id) ON DELETE CASCADE,
    login_name  varchar(100) NOT NULL
);

CREATE VIEW customer_export AS
SELECT id, email, legacy_code FROM customer;

INSERT INTO customer (email, legacy_code)
SELECT 'user' || g || '@example.com', 'LC-' || g FROM generate_series(1, 10000) AS g;

INSERT INTO customer_legacy_login (customer_id, login_name)
SELECT id, 'login' || id FROM customer WHERE id % 2 = 0;

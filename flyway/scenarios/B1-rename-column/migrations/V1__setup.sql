-- Old model: the column is called "mail". Goal: rename it to "email" without downtime.
CREATE TABLE customer (
    id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mail varchar(255) NOT NULL
);

INSERT INTO customer (mail)
SELECT 'user' || g || '@example.com' FROM generate_series(1, 10000) AS g;

CREATE TABLE customer (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email varchar(255) NOT NULL
);

INSERT INTO customer (email)
SELECT 'user' || g || '@example.com' FROM generate_series(1, 200000) AS g;

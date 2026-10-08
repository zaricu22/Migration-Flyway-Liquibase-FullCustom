CREATE TABLE customer (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email      varchar(255) NOT NULL,
    created_at timestamptz  NOT NULL DEFAULT now()
);

INSERT INTO customer (email)
SELECT 'user' || g || '@example.com' FROM generate_series(1, 1000) AS g;

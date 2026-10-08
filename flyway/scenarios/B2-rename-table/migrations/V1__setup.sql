-- Old model: the table is called "item". Goal: rename it to "product" without downtime.
CREATE TABLE item (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name  varchar(200)  NOT NULL,
    price numeric(12,2) NOT NULL
);

INSERT INTO item (name, price)
SELECT 'Item ' || g, round((random() * 100 + 1)::numeric, 2) FROM generate_series(1, 1000) AS g;

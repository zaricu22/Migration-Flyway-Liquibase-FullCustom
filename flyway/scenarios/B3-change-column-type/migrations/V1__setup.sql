CREATE TABLE orders (
    id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    note   varchar(50),
    amount double precision NOT NULL      -- money in a float: the classic mistake
);

INSERT INTO orders (note, amount)
SELECT 'order ' || g, (random() * 1000)::numeric(12,2)::float8 + 0.1 + 0.2   -- float noise
FROM generate_series(1, 200000) AS g;

CREATE TABLE _demo_filenode (step text PRIMARY KEY, filenode oid NOT NULL);
INSERT INTO _demo_filenode VALUES ('1 after V1', pg_relation_filenode('orders'));

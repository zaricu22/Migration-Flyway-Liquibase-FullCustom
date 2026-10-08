CREATE TABLE orders (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id bigint      NOT NULL,
    status      varchar(20) NOT NULL,
    created_at  timestamptz NOT NULL
);

INSERT INTO orders (customer_id, status, created_at)
SELECT (random() * 10000)::int + 1,
       (ARRAY['new', 'paid', 'shipped'])[1 + (g % 3)],
       now() - (g || ' minutes')::interval
FROM generate_series(1, 300000) AS g;

ANALYZE orders;

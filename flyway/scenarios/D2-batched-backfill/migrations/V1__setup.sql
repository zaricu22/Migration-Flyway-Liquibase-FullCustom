CREATE TABLE orders (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    created_at   timestamptz NOT NULL,
    amount_cents bigint      NOT NULL
);

INSERT INTO orders (created_at, amount_cents)
SELECT now() - (g || ' minutes')::interval, (random() * 100000)::bigint
FROM generate_series(1, 500000) AS g;

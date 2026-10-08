-- Starting model: orders without a status.
CREATE TABLE orders (
    id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ordered  date NOT NULL,
    amount   numeric(12,2) NOT NULL
);

INSERT INTO orders (ordered, amount)
SELECT date '2026-01-01' + (g % 200), (g % 500) + 0.99 FROM generate_series(1, 1000) AS g;

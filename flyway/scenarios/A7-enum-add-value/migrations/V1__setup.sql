CREATE TYPE order_status AS ENUM ('new', 'paid', 'shipped');

CREATE TABLE orders (
    id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status order_status NOT NULL DEFAULT 'new'
);

INSERT INTO orders (status)
SELECT (ARRAY['new', 'paid', 'shipped']::order_status[])[1 + (g % 3)]
FROM generate_series(1, 1000) AS g;

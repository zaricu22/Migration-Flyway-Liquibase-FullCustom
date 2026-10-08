-- Old model: the status is an enum. The business retires 'on_hold' (those orders go back to 'new'),
-- and new statuses should become possible without DDL. PostgreSQL can add enum values (A7),
-- but it can't remove one.
CREATE TYPE order_status AS ENUM ('new', 'paid', 'shipped', 'on_hold', 'cancelled');

CREATE TABLE orders (
    id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    amount numeric(12,2) NOT NULL,
    status order_status NOT NULL DEFAULT 'new'
);

-- 10,000 orders, 200 of them 'on_hold'
INSERT INTO orders (amount, status)
SELECT (g % 500) + 0.99,
       CASE WHEN g % 50 = 0 THEN 'on_hold'
            ELSE (ARRAY['new', 'paid', 'shipped', 'cancelled'])[1 + g % 4] END::order_status
FROM generate_series(1, 10000) AS g;

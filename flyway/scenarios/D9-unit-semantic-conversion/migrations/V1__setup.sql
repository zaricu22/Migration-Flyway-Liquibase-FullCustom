-- Two silent-corruption traps:
--   created_at: "timestamp without time zone", written by an app running in Europe/Belgrade
--               -> the values are Belgrade local time, but nothing in the database says so
--   price:      euros in a double precision column
CREATE TABLE orders (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    created_at timestamp        NOT NULL,
    price      double precision NOT NULL
);

INSERT INTO orders (created_at, price) VALUES
    ('2025-07-01 12:00:00', 0.29),   -- summer (UTC+2)
    ('2025-01-15 12:00:00', 0.57),   -- winter (UTC+1)
    ('2025-10-26 02:30:00', 1.15),   -- AMBIGUOUS: clocks go 03:00 -> 02:00, this happened twice
    ('2025-03-30 02:30:00', 4.35),   -- NONEXISTENT: clocks jump 02:00 -> 03:00
    ('2025-05-05 08:15:00', 19.99);

INSERT INTO orders (created_at, price)
SELECT timestamp '2024-01-01' + (g || ' hours')::interval, (1 + g % 5000) / 100.0
FROM generate_series(1, 50000) AS g;

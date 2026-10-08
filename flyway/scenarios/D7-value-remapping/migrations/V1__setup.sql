-- Legacy status codes: single letters plus a historical synonym ('PEND' = 'N').
-- Goal: readable codes. One legacy code splits in two: 'X' = cancelled OR refunded,
-- depending on refunded_at.
CREATE TABLE orders (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status      varchar(20) NOT NULL,
    refunded_at timestamptz
);

INSERT INTO orders (status, refunded_at)
SELECT (ARRAY['N', 'P', 'S', 'X', 'PEND'])[1 + g % 5],
       CASE WHEN g % 5 = 3 AND g % 2 = 0 THEN now() - interval '1 day' END
FROM generate_series(1, 100000) AS g;

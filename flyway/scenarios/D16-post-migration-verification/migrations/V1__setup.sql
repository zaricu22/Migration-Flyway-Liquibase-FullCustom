-- Legacy denormalized table: one row per order LINE, header fields repeated on every line.
-- Goal: split into orders + order_line, and PROVE nothing was lost or changed.
CREATE TABLE legacy_order_line (
    order_no       varchar(20)   NOT NULL,
    customer_email varchar(255)  NOT NULL,
    order_date     date          NOT NULL,
    sku            varchar(20)   NOT NULL,
    qty            int           NOT NULL,
    unit_price     numeric(12,2) NOT NULL
);

INSERT INTO legacy_order_line
SELECT 'ORD-' || o, 'customer' || (o % 3000) || '@example.com', date '2024-01-01' + o % 600,
       'SKU-' || ((o * 7 + l) % 500), 1 + (o + l) % 4, 5 + ((o * l) % 200)
FROM generate_series(1, 20000) AS o,
     generate_series(1, 1 + o % 5) AS l;

-- Legit data that looks like a duplicate: the same product twice on one order (e.g. two
-- separate scans at the till). A careless DISTINCT would silently merge these lines.
INSERT INTO legacy_order_line
SELECT order_no, customer_email, order_date, sku, qty, unit_price
FROM (
    SELECT l.*, row_number() OVER (PARTITION BY order_no ORDER BY sku) AS rn
    FROM legacy_order_line l
    WHERE order_no IN (SELECT 'ORD-' || g FROM generate_series(97, 20000, 97) AS g)
) first_line
WHERE rn = 1;

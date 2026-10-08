-- 5 years of orders in the hot table. Goal: move everything older than 2 years (orders AND
-- their items) into archive tables, in batches, without losing a row.
CREATE TABLE orders (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    created_at timestamptz   NOT NULL,
    total      numeric(12,2) NOT NULL
);

CREATE TABLE order_item (
    id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id bigint NOT NULL REFERENCES orders (id),
    sku      varchar(20) NOT NULL,
    quantity int         NOT NULL
);
CREATE INDEX order_item_order_id_idx ON order_item (order_id);
CREATE INDEX orders_created_at_idx ON orders (created_at);

INSERT INTO orders (created_at, total)
SELECT now() - (g * 10 || ' minutes')::interval, 10 + g % 490
FROM generate_series(1, 250000) AS g;               -- ~4.75 years back

INSERT INTO order_item (order_id, sku, quantity)
SELECT o.id, 'SKU-' || (o.id % 1000 + i), 1 + i
FROM orders o, generate_series(1, 2) AS i;

-- Expected totals for verify.sql
CREATE TABLE _demo_expected AS
SELECT (SELECT count(*) FROM orders) AS orders, (SELECT sum(total) FROM orders) AS order_total,
       (SELECT count(*) FROM order_item) AS items;

CREATE TABLE orders (
    id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_no       varchar(20)  NOT NULL UNIQUE,
    customer_email varchar(255) NOT NULL,
    order_date     date         NOT NULL
);

CREATE TABLE order_line (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,   -- surrogate: the same SKU may appear twice
    order_id   bigint        NOT NULL REFERENCES orders (id),
    sku        varchar(20)   NOT NULL,
    qty        int           NOT NULL,
    unit_price numeric(12,2) NOT NULL
);
CREATE INDEX order_line_order_id_idx ON order_line (order_id);

-- The verification is a FUNCTION so it can be re-run any time later (and by demo_broken_transform.sql).
-- It compares source and target on independent invariants and RAISES on the first mismatch.
CREATE FUNCTION verify_order_migration() RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    src bigint; dst bigint;
    src_sum numeric; dst_sum numeric;
    src_hash text; dst_hash text;
    diff bigint;
BEGIN
    -- 1. row counts: orders
    SELECT count(DISTINCT order_no) INTO src FROM legacy_order_line;
    SELECT count(*) INTO dst FROM orders;
    IF src <> dst THEN RAISE EXCEPTION 'orders: % in source, % migrated', src, dst; END IF;

    -- 2. row counts: lines
    SELECT count(*) INTO src FROM legacy_order_line;
    SELECT count(*) INTO dst FROM order_line;
    IF src <> dst THEN RAISE EXCEPTION 'lines: % in source, % migrated', src, dst; END IF;

    -- 3. business total
    SELECT sum(qty * unit_price) INTO src_sum FROM legacy_order_line;
    SELECT sum(qty * unit_price) INTO dst_sum FROM order_line;
    IF src_sum <> dst_sum THEN RAISE EXCEPTION 'grand total: % in source, % migrated', src_sum, dst_sum; END IF;

    -- 4. per-order totals, both directions (catches errors that cancel out in the grand total)
    SELECT count(*) INTO diff FROM (
        (SELECT order_no, sum(qty * unit_price) FROM legacy_order_line GROUP BY order_no
         EXCEPT
         SELECT o.order_no, sum(l.qty * l.unit_price) FROM orders o JOIN order_line l ON l.order_id = o.id GROUP BY o.order_no)
        UNION ALL
        (SELECT o.order_no, sum(l.qty * l.unit_price) FROM orders o JOIN order_line l ON l.order_id = o.id GROUP BY o.order_no
         EXCEPT
         SELECT order_no, sum(qty * unit_price) FROM legacy_order_line GROUP BY order_no)
    ) d;
    IF diff > 0 THEN RAISE EXCEPTION 'per-order totals differ for % orders', diff; END IF;

    -- 5. fingerprint: hash of every value, sorted, on both sides (catches swapped/changed values)
    SELECT md5(string_agg(concat_ws('|', order_no, customer_email, order_date, sku, qty, unit_price), ','
                          ORDER BY order_no, sku, qty, unit_price))
    INTO src_hash FROM legacy_order_line;
    SELECT md5(string_agg(concat_ws('|', o.order_no, o.customer_email, o.order_date, l.sku, l.qty, l.unit_price), ','
                          ORDER BY o.order_no, l.sku, l.qty, l.unit_price))
    INTO dst_hash FROM orders o JOIN order_line l ON l.order_id = o.id;
    IF src_hash <> dst_hash THEN RAISE EXCEPTION 'fingerprint mismatch: % vs %', src_hash, dst_hash; END IF;

    -- 6. structural: no order without lines
    IF EXISTS (SELECT 1 FROM orders o WHERE NOT EXISTS (SELECT 1 FROM order_line l WHERE l.order_id = o.id)) THEN
        RAISE EXCEPTION 'orders without lines';
    END IF;

    RAISE NOTICE 'verification passed: counts, totals, per-order totals, fingerprint, structure';
END $$;

-- PRE-CHECK: the header must be identical on every line of an order, otherwise "one row per
-- order" is ambiguous (which email wins?). Fail instead of guessing.
DO $$
DECLARE
    inconsistent bigint;
BEGIN
    SELECT count(*) INTO inconsistent FROM (
        SELECT order_no FROM legacy_order_line
        GROUP BY order_no HAVING count(DISTINCT (customer_email, order_date)) > 1
    ) t;
    IF inconsistent > 0 THEN
        RAISE EXCEPTION '% orders have conflicting header data across their lines', inconsistent;
    END IF;
END $$;

-- TRANSFORM
INSERT INTO orders (order_no, customer_email, order_date)
SELECT DISTINCT order_no, customer_email, order_date FROM legacy_order_line;

INSERT INTO order_line (order_id, sku, qty, unit_price)
SELECT o.id, l.sku, l.qty, l.unit_price                -- no DISTINCT here: identical lines are legit
FROM legacy_order_line l
JOIN orders o ON o.order_no = l.order_no;

-- VERIFY in the SAME transaction: if anything is off, the exception rolls back the whole
-- migration: no half-migrated data, and Flyway reports the reason.
SELECT verify_order_migration();

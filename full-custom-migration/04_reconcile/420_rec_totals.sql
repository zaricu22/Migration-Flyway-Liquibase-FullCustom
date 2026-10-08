-- (results go to mig.reconciliation; the gate prints them)
\o /dev/null
-- TOTALS: business sums must survive the transformation.
-- The raw side is computed INDEPENDENTLY of the transform functions (a plain replace + cast), so a
-- bug in mig.parse_amount_cents would show up here instead of being repeated on both sides.
WITH raw_accepted AS (
    SELECT l.order_no,
           btrim(l.qty)::int * round(replace(btrim(l.unit_price), ',', '.')::numeric * 100) AS amount
    FROM raw.v_order_lines l
    WHERE NOT EXISTS (SELECT 1 FROM mig.v_rejected r WHERE r.entity = 'order' AND r.source_key = l.order_no)
)
SELECT mig.check('reconcile', 'order amount total (cents): raw accepted = staged',
    (SELECT sum(amount) FROM raw_accepted),
    (SELECT sum(qty * unit_price_cents)::numeric FROM stg.order_line));

-- Per-order totals in BOTH directions: errors that cancel out in the grand total show up here.
WITH raw_per_order AS (
    SELECT l.order_no,
           sum(btrim(l.qty)::int * round(replace(btrim(l.unit_price), ',', '.')::numeric * 100)) AS amount
    FROM raw.v_order_lines l
    WHERE NOT EXISTS (SELECT 1 FROM mig.v_rejected r WHERE r.entity = 'order' AND r.source_key = l.order_no)
    GROUP BY l.order_no
), stg_per_order AS (
    SELECT order_no, sum(qty * unit_price_cents)::numeric AS amount FROM stg.order_line GROUP BY order_no
)
SELECT mig.check('reconcile', 'per-order totals: mismatching orders', 0::bigint,
    (SELECT count(*) FROM ((SELECT * FROM raw_per_order EXCEPT SELECT * FROM stg_per_order)
                           UNION ALL
                           (SELECT * FROM stg_per_order EXCEPT SELECT * FROM raw_per_order)) d));

-- Products: sum of prices of accepted products
SELECT mig.check('reconcile', 'product price total (cents): raw accepted = staged',
    (SELECT sum(round(replace(btrim(price), ',', '.')::numeric * 100)) FROM raw.v_products p
     WHERE NOT EXISTS (SELECT 1 FROM mig.v_rejected r WHERE r.entity = 'product' AND r.source_key = p.sku)),
    (SELECT sum(price_cents)::numeric FROM stg.product));

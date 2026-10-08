-- GATE 1: some rejected records are normal. Many mean the RULES are wrong (e.g. a whole export in
-- an unexpected format), and migrating anyway would silently lose data. Threshold: 5 % per entity.
\echo 'Findings of this run:'
SELECT entity, rule, severity, count(DISTINCT source_key) AS records
FROM mig.error
WHERE run_id = mig.current_run() AND phase = 'validate'
GROUP BY entity, rule, severity
ORDER BY entity, severity, rule;

\o /dev/null
WITH totals AS (
    SELECT 'customer' AS entity, count(*) AS total FROM raw.v_customers
    UNION ALL SELECT 'product', count(*) FROM raw.v_products
    UNION ALL SELECT 'order', count(DISTINCT order_no) FROM raw.v_order_lines
)
SELECT mig.check('validate',
                 'reject rate ' || t.entity || ' <= 5 %',
                 true,
                 (SELECT count(*) FROM mig.v_rejected r WHERE r.entity = t.entity) <= t.total * 0.05)
FROM totals t;
\o

\echo 'Reject rates:'
WITH totals AS (
    SELECT 'customer' AS entity, count(*) AS total FROM raw.v_customers
    UNION ALL SELECT 'product', count(*) FROM raw.v_products
    UNION ALL SELECT 'order', count(DISTINCT order_no) FROM raw.v_order_lines
)
SELECT t.entity, t.total, count(r.source_key) AS rejected,
       round(100.0 * count(r.source_key) / t.total, 2) AS pct
FROM totals t LEFT JOIN mig.v_rejected r ON r.entity = t.entity
GROUP BY t.entity, t.total ORDER BY t.entity;

\o /dev/null
SELECT mig.gate('validate');

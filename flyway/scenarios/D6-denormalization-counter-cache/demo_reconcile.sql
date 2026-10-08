-- Reconciliation: find and fix customers whose cached values drifted from the truth.
-- Safe to run any time; touches only the rows that are wrong.

\echo '--- Simulate drift: a bulk import that bypassed triggers (session_replication_role = replica)'
SET session_replication_role = replica;
INSERT INTO orders (customer_id, created_at)
SELECT 1 + g % 50, now() FROM generate_series(1, 500) AS g;
RESET session_replication_role;
\echo '--- Drifted customers before the fix'
WITH truth AS (
    SELECT c.id, count(o.id) AS cnt, max(o.created_at) AS last_at
    FROM customer c LEFT JOIN orders o ON o.customer_id = c.id
    GROUP BY c.id
)
SELECT count(*) AS drifted
FROM customer c JOIN truth t ON t.id = c.id
WHERE (c.orders_count, c.last_order_at) IS DISTINCT FROM (t.cnt, t.last_at);

\echo '--- Fix'
WITH truth AS (
    SELECT c.id, count(o.id) AS cnt, max(o.created_at) AS last_at
    FROM customer c LEFT JOIN orders o ON o.customer_id = c.id
    GROUP BY c.id
)
UPDATE customer c
SET orders_count = t.cnt, last_order_at = t.last_at
FROM truth t
WHERE t.id = c.id
  AND (c.orders_count, c.last_order_at) IS DISTINCT FROM (t.cnt, t.last_at);

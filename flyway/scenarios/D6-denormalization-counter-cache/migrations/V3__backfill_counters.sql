-- Backfill with ABSOLUTE values computed from the source of truth.
--
-- RACE: this statement reads orders as of its start. An order inserted concurrently can be
-- counted by the trigger AND then overwritten by this absolute value (or the other way round),
-- so the counter ends up off by one. With live traffic, always run the reconciliation
-- (demo_reconcile.sql) after the backfill, and schedule it as a periodic job later.
UPDATE customer c
SET orders_count  = s.cnt,
    last_order_at = s.last_at
FROM (
    SELECT customer_id, count(*) AS cnt, max(created_at) AS last_at
    FROM orders GROUP BY customer_id
) s
WHERE c.id = s.customer_id
  AND (c.orders_count, c.last_order_at) IS DISTINCT FROM (s.cnt, s.last_at);

-- Run after V4: a new status is DATA now, not DDL. No ALTER TYPE, no migration with a lock.
-- (With Flyway, such reference rows still belong in a migration or an R__ script, see D1.)
INSERT INTO order_status_code (code, label, sort_order) VALUES ('refunded', 'Refunded', 60)
ON CONFLICT (code) DO NOTHING;
UPDATE orders SET status_code = 'refunded' WHERE id = 3;

SELECT s.sort_order, s.code, s.label, count(o.id) AS orders
FROM order_status_code s LEFT JOIN orders o ON o.status_code = s.code
GROUP BY 1, 2, 3 ORDER BY 1;

-- Queries of the NEW application (knows only "status_code" and the lookup table). Row 1 shows changes made by app v1.
-- Works after V2 (once backfilled, V3), and after V4.
\echo '--- app v2: insert + update using the code, label from the lookup table'
INSERT INTO orders (amount, status_code) VALUES (20.00, 'paid');
UPDATE orders SET status_code = 'cancelled' WHERE id = 2;
SELECT o.id, o.status_code, s.label
FROM orders o JOIN order_status_code s ON s.code = o.status_code
WHERE o.id IN (1, 2) OR o.id = (SELECT max(id) FROM orders) ORDER BY o.id;

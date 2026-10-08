-- Queries of the OLD application (knows only the enum column "status"). Row 2 shows changes made by app v2.
-- Works after V1, V2, V3. Fails after V4.
\echo '--- app v1: insert + update using the enum'
INSERT INTO orders (amount, status) VALUES (10.00, 'paid');
UPDATE orders SET status = 'shipped' WHERE id = 1;
SELECT id, status FROM orders WHERE id IN (1, 2) OR id = (SELECT max(id) FROM orders) ORDER BY id;

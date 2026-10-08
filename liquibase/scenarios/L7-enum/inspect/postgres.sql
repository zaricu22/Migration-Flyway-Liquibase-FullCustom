\echo 'ORDER BY status sorts by DECLARATION order (new, paid, shipped, cancelled):'
SELECT id, status FROM orders ORDER BY status;
\echo 'Invalid value:'
INSERT INTO orders (id, status) VALUES (9, 'lost');

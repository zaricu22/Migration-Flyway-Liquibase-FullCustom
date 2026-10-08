-- Application traffic: insert, move and delete orders. The trigger keeps the counters right.
\echo '--- customer 1 and 2 before'
SELECT id, orders_count, last_order_at FROM customer WHERE id IN (1, 2) ORDER BY id;

INSERT INTO orders (customer_id, created_at) VALUES (1, now());
UPDATE orders SET customer_id = 2 WHERE id = (SELECT min(id) FROM orders WHERE customer_id = 1);
DELETE FROM orders WHERE id = (SELECT max(id) FROM orders WHERE customer_id = 1);

\echo '--- after: +1 new, -1 moved to customer 2, -1 deleted (last_order_at recomputed)'
SELECT id, orders_count, last_order_at FROM customer WHERE id IN (1, 2) ORDER BY id;

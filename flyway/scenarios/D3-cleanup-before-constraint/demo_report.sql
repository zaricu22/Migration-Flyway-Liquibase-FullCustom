-- Run after V1: what would break, and how badly? Always measure before writing cleanup rules.
\echo '--- Violations per future constraint'
SELECT 'orders.customer_id FK' AS rule, count(*) AS violations
FROM orders o WHERE NOT EXISTS (SELECT 1 FROM customer c WHERE c.id = o.customer_id)
UNION ALL
SELECT 'orders.quantity > 0', count(*) FROM orders WHERE quantity <= 0
UNION ALL
SELECT 'orders.status IN (...)', count(*) FROM orders WHERE status NOT IN ('new', 'paid', 'shipped', 'cancelled')
UNION ALL
SELECT 'customer.email NOT NULL', count(*) FROM customer WHERE email IS NULL;

\echo '--- Distinct invalid statuses (to write the mapping rules)'
SELECT status, count(*) FROM orders
WHERE status NOT IN ('new', 'paid', 'shipped', 'cancelled') GROUP BY status ORDER BY 2 DESC;

\echo '--- Adding a constraint directly fails on the first bad row'
\set ON_ERROR_STOP off
BEGIN;
ALTER TABLE orders ADD CONSTRAINT orders_customer_id_fk FOREIGN KEY (customer_id) REFERENCES customer (id);
ROLLBACK;

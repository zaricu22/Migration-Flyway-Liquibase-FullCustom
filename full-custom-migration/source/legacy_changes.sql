-- Changes that happen in the OLD system after the initial extract (the app is still running there).
-- Applied by ./run.sh delta before the incremental extract (07_cutover/710_delta_sync.sql).
-- Every changed row gets a new updated_at, which is what the delta extract looks for.

-- 1. A customer changes the e-mail address
UPDATE legacy.customers SET email = 'new.user150@example.com', updated_at = now() WHERE cust_no = 150;

-- 2. Somebody FIXED a record that was rejected in the initial run (e-mail without @).
--    Its orders were rejected too ("customer_rejected") and must now be accepted.
UPDATE legacy.customers SET email = 'user250@example.com', updated_at = now() WHERE cust_no = 250;

-- 3. A new customer signs up
INSERT INTO legacy.customers VALUES
    (2001, 'Late Signup', 'late.signup@example.com', '+381 65 1234567', 'New Road 1, 11000 Belgrade',
     'RS', '2026-09-01', 'A', now())
ON CONFLICT (cust_no) DO UPDATE SET updated_at = now();

-- 4. An order gets shipped (status on every line of the order)
UPDATE legacy.order_lines SET status_code = 'S', updated_at = now() WHERE order_no = 'ORD-000010';

-- 5. The new customer orders something
INSERT INTO legacy.order_lines VALUES
    ('ORD-006001', 1, 2001, '2026-09-02', 'P', 'SKU-0001', '2', (SELECT price FROM legacy.products WHERE sku = 'SKU-0001'), now()),
    ('ORD-006001', 2, 2001, '2026-09-02', 'P', 'SKU-0003', '1', (SELECT price FROM legacy.products WHERE sku = 'SKU-0003'), now())
ON CONFLICT (order_no, line_no) DO UPDATE SET updated_at = now();

-- DELETES leave no updated_at behind: only the full key comparison of the delta finds them.
-- 6. An order is purged from the old system (all its lines)
DELETE FROM legacy.order_lines WHERE order_no = 'ORD-000020';

-- 7. One line is removed from an order (ORD-000011 had 4 lines)
DELETE FROM legacy.order_lines WHERE order_no = 'ORD-000011' AND line_no = 4;

-- 8. A customer is deleted together with all of their orders
DELETE FROM legacy.order_lines WHERE cust_no = 301;
DELETE FROM legacy.customers   WHERE cust_no = 301;

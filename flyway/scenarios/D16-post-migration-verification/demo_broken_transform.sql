-- Run after V2 (before V3): re-does the line transform with a classic bug, then runs the same
-- verification. Everything is rolled back afterwards.
\set ON_ERROR_STOP off
BEGIN;
TRUNCATE order_line;

-- BUG: DISTINCT "to be safe" silently merges legit identical lines (same SKU twice on one order).
INSERT INTO order_line (order_id, sku, qty, unit_price)
SELECT DISTINCT o.id, l.sku, l.qty, l.unit_price
FROM legacy_order_line l
JOIN orders o ON o.order_no = l.order_no;

\echo '--- The verification catches it:'
SELECT verify_order_migration();
ROLLBACK;

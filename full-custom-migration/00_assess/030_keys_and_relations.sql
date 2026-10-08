-- 0 ASSESS: keys and relationships. The old system enforces none of them (no FKs, no unique
-- e-mail, a repeated order header), so the data has to be checked before the new model can.
SET TRANSACTION READ ONLY;

\echo '=== Duplicate customers: same e-mail after lower() + trim()'
SELECT count(*) AS duplicate_groups, coalesce(sum(n - 1), 0) AS extra_rows, min(example) AS example
FROM (SELECT lower(btrim(email)) AS norm_email, count(*) AS n, min(email) AS example
      FROM src.customers GROUP BY 1 HAVING count(*) > 1) d;

\echo '=== Orphans: order lines pointing at customers / products that do not exist'
SELECT 'unknown customer' AS problem, count(DISTINCT l.order_no) AS orders, count(*) AS lines, min(l.cust_no) AS example
FROM src.order_lines l
WHERE NOT EXISTS (SELECT 1 FROM src.customers c WHERE c.cust_no = l.cust_no)
UNION ALL
SELECT 'unknown product', count(DISTINCT l.order_no), count(*), NULL
FROM src.order_lines l
WHERE NOT EXISTS (SELECT 1 FROM src.products p WHERE p.sku = l.sku);

\echo '=== Inconsistent order headers: one order, different header values on its lines'
SELECT order_no,
       count(DISTINCT cust_no) AS customers,
       count(DISTINCT order_date) AS dates,
       count(DISTINCT status_code) AS statuses
FROM src.order_lines
GROUP BY order_no
HAVING count(DISTINCT cust_no) > 1 OR count(DISTINCT order_date) > 1 OR count(DISTINCT status_code) > 1
ORDER BY order_no;

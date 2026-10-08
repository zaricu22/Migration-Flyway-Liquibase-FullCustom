-- 0 ASSESS: every distinct value of the code-like columns, with counts.
-- This list goes to the business: each value needs a target code (00_setup/004_code_maps.sql)
-- or a decision to reject it.
SET TRANSACTION READ ONLY;

\echo '=== Countries (free text)'
SELECT country AS value, lower(btrim(country)) AS normalized, count(*) AS customers
FROM src.customers GROUP BY 1, 2 ORDER BY 2, 1;

\echo '=== Order status codes'
SELECT status_code AS value, count(DISTINCT order_no) AS orders
FROM src.order_lines GROUP BY 1 ORDER BY 1;

\echo '=== Product categories (spellings that collapse after lower() + trim())'
SELECT lower(btrim(category)) AS normalized, count(DISTINCT category) AS spellings,
       string_agg(DISTINCT '"' || category || '"', ', ') AS as_written, count(*) AS products
FROM src.products GROUP BY 1 ORDER BY 1;

\echo '=== Customer active flag'
SELECT active AS value, count(*) AS customers FROM src.customers GROUP BY 1 ORDER BY 1;

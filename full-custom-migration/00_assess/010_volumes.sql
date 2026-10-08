-- 0 ASSESS: profile the OLD system BEFORE writing any rule. Read-only: nothing is changed or stored,
-- the output is the input for the rules (02_validate), the mappings (004_code_maps) and the planning
-- (how big, how long, batching needed?). Reads the source through the foreign tables in src.
SET TRANSACTION READ ONLY;

\echo '=== Volumes and change timestamps'
SELECT 'customers' AS source_table, count(*) AS rows, min(updated_at) AS oldest_change, max(updated_at) AS newest_change
FROM src.customers
UNION ALL
SELECT 'order_lines', count(*), min(updated_at), max(updated_at) FROM src.order_lines
UNION ALL
SELECT 'products (no updated_at!)', count(*), NULL, NULL FROM src.products;

\echo '=== Orders: the order header is repeated on every line'
SELECT count(DISTINCT order_no) AS orders,
       count(*) AS lines,
       round(count(*)::numeric / count(DISTINCT order_no), 2) AS avg_lines_per_order,
       max(line_no) AS max_line_no
FROM src.order_lines;

\echo '=== Missing values per column (NULL or blank)'
SELECT 'customers' AS source_table, v.col, count(*) FILTER (WHERE nullif(btrim(v.val), '') IS NULL) AS missing, count(*) AS rows
FROM src.customers c,
     LATERAL (VALUES ('full_name', c.full_name), ('email', c.email), ('phone', c.phone),
                     ('address', c.address), ('country', c.country), ('created', c.created)) AS v(col, val)
GROUP BY v.col
UNION ALL
SELECT 'products', v.col, count(*) FILTER (WHERE nullif(btrim(v.val), '') IS NULL), count(*)
FROM src.products p,
     LATERAL (VALUES ('title', p.title), ('price', p.price), ('category', p.category)) AS v(col, val)
GROUP BY v.col
UNION ALL
SELECT 'order_lines', v.col, count(*) FILTER (WHERE nullif(btrim(v.val), '') IS NULL), count(*)
FROM src.order_lines l,
     LATERAL (VALUES ('order_date', l.order_date), ('status_code', l.status_code), ('sku', l.sku),
                     ('qty', l.qty), ('unit_price', l.unit_price)) AS v(col, val)
GROUP BY v.col
ORDER BY 1, 2;

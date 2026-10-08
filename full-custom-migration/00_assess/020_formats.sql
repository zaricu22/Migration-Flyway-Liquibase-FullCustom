-- 0 ASSESS: which FORMATS does each text column really contain?
-- "Shape" profiling: every digit becomes 9 and every letter A, so '31.02.2021' and '01.01.2019' share
-- the shape '99.99.9999'. A handful of shapes per column = a handful of parsing rules to write.
SET TRANSACTION READ ONLY;

\echo '=== Value shapes per column (digit -> 9, letter -> A), the 6 most common'
WITH v (col, val) AS (
    SELECT 'customers.created', created FROM src.customers
    UNION ALL SELECT 'customers.phone', phone FROM src.customers
    UNION ALL SELECT 'products.price', price FROM src.products
    UNION ALL SELECT 'order_lines.order_date', order_date FROM src.order_lines
    UNION ALL SELECT 'order_lines.qty', qty FROM src.order_lines
), shapes AS (
    SELECT col,
           coalesce(regexp_replace(regexp_replace(val, '[0-9]', '9', 'g'), '[A-Za-z]', 'A', 'g'), '<NULL>') AS shape,
           count(*) AS rows,
           min(val) AS example
    FROM v
    GROUP BY 1, 2
)
SELECT col, shape, rows, example
FROM (SELECT s.*, row_number() OVER (PARTITION BY col ORDER BY rows DESC, shape) AS rn FROM shapes s) ranked
WHERE rn <= 6
ORDER BY col, rows DESC;

\echo '=== E-mail quality'
SELECT count(*) AS customers,
       count(*) FILTER (WHERE email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$') AS not_an_email,
       count(*) FILTER (WHERE email <> lower(email))                AS upper_case,
       count(*) FILTER (WHERE email <> btrim(email))                AS surrounding_spaces
FROM src.customers;

\echo '=== Free-text addresses: do they follow "street, zip city"?'
SELECT count(*) FILTER (WHERE btrim(address) ~ '^(.+?),\s*(\d{4,6})\s+(.+)$')        AS parseable,
       count(*) FILTER (WHERE NOT (coalesce(btrim(address), '') ~ '^(.+?),\s*(\d{4,6})\s+(.+)$')) AS not_parseable,
       min(address) FILTER (WHERE NOT (coalesce(btrim(address), '') ~ '^(.+?),\s*(\d{4,6})\s+(.+)$')) AS example
FROM src.customers;

\echo '=== Names: how many words?'
SELECT array_length(regexp_split_to_array(btrim(full_name), '\s+'), 1) AS words, count(*) AS customers, min(full_name) AS example
FROM src.customers
GROUP BY 1 ORDER BY 1;

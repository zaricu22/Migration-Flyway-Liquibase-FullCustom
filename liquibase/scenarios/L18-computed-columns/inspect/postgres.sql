SELECT * FROM order_line ORDER BY id;
UPDATE order_line SET qty = 4 WHERE id = 1;
\echo 'after qty 3 -> 4 (recomputed on write):'
SELECT id, qty, line_total, line_label FROM order_line WHERE id = 1;
\echo 'Writing a computed column -> rejected:'
UPDATE order_line SET line_total = 0 WHERE id = 1;
\echo 'concat() is not IMMUTABLE -> not allowed in a generated column:'
ALTER TABLE order_line ADD label2 text GENERATED ALWAYS AS (concat(sku, ' x ', qty)) STORED;

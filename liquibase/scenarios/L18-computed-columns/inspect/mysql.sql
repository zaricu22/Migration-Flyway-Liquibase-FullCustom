SELECT * FROM order_line ORDER BY id;
UPDATE order_line SET qty = 4 WHERE id = 1;
-- after qty 3 -> 4 (STORED recomputed on write, VIRTUAL computed on read):
SELECT id, qty, line_total, line_label FROM order_line WHERE id = 1;
-- Writing a computed column -> rejected:
UPDATE order_line SET line_total = 0 WHERE id = 1;

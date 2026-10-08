SET NOCOUNT ON;
-- PERSISTED computed columns need QUOTED_IDENTIFIER ON for writes, like filtered indexes (see L16).
SET QUOTED_IDENTIFIER ON;
SELECT * FROM order_line ORDER BY id;
UPDATE order_line SET qty = 4 WHERE id = 1;
-- after qty 3 -> 4 (PERSISTED recomputed on write, non-persisted computed on read):
SELECT id, qty, line_total, line_label FROM order_line WHERE id = 1;
GO
-- Writing a computed column -> rejected:
UPDATE order_line SET line_total = 0 WHERE id = 1;
GO

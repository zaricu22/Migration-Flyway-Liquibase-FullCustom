SET NOCOUNT ON;
-- varchar: ORDER BY status is ALPHABETICAL (cancelled, new, paid, shipped)
SELECT id, status FROM orders ORDER BY status;
-- Invalid value: rejected by the CHECK
INSERT INTO orders (id, status) VALUES (9, 'lost');

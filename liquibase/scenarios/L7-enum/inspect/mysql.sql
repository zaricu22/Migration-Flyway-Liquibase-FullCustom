-- ORDER BY status sorts by the enum's INDEX (declaration order), not alphabetically:
SELECT id, status FROM orders ORDER BY status;
-- Invalid value (strict mode): rejected
INSERT INTO orders (id, status) VALUES (9, 'lost');

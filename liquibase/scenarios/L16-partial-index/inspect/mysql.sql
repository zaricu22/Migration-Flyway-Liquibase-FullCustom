INSERT INTO account (id, email, deleted_at) VALUES (1, 'ana@example.com', NOW() - INTERVAL 1 YEAR);  -- deleted
INSERT INTO account (id, email, deleted_at) VALUES (2, 'ana@example.com', NOW() - INTERVAL 1 DAY);   -- deleted again: OK
INSERT INTO account (id, email, deleted_at) VALUES (3, 'ana@example.com', NULL);                     -- active: OK
-- Second ACTIVE account with the same email -> rejected:
INSERT INTO account (id, email, deleted_at) VALUES (4, 'ana@example.com', NULL);
-- NOTE: INSERT needs a column list now: the generated column can't receive a value.
SELECT * FROM account ORDER BY id;

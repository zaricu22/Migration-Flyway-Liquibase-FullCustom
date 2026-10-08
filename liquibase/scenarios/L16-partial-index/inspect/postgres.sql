INSERT INTO account VALUES (1, 'ana@example.com', now() - interval '1 year');   -- deleted
INSERT INTO account VALUES (2, 'ana@example.com', now() - interval '1 day');    -- deleted again: OK
INSERT INTO account VALUES (3, 'ana@example.com', NULL);                        -- active: OK
\echo 'Second ACTIVE account with the same email -> rejected:'
INSERT INTO account VALUES (4, 'ana@example.com', NULL);
SELECT * FROM account ORDER BY id;

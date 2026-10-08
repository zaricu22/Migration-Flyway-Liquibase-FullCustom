-- Queries of the NEW application (knows only "email"). Row 1 shows changes made by app v1. Works after V2 (once backfilled, V3), and after V4.
\echo '--- app v2: insert + update using email'
INSERT INTO customer (email) VALUES ('app-v2-' || floor(random() * 1e6) || '@example.com');
UPDATE customer SET email = 'changed-by-v2@example.com' WHERE id = 2;
SELECT id, email FROM customer WHERE id IN (1, 2) OR id = (SELECT max(id) FROM customer) ORDER BY id;

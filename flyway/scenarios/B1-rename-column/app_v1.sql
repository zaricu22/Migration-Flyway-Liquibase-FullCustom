-- Queries of the OLD application (knows only "mail"). Row 2 shows changes made by app v2. Works after V1, V2, V3. Fails after V4.
\echo '--- app v1: insert + update using mail'
INSERT INTO customer (mail) VALUES ('app-v1-' || floor(random() * 1e6) || '@example.com');
UPDATE customer SET mail = 'changed-by-v1@example.com' WHERE id = 1;
SELECT id, mail FROM customer WHERE id IN (1, 2) OR id = (SELECT max(id) FROM customer) ORDER BY id;

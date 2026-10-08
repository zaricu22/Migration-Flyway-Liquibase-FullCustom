SELECT * FROM event_user ORDER BY id;
\echo 'jsonb normalizes the document (key order, whitespace, duplicate keys):'
SELECT payload FROM event WHERE id = 1;
\echo 'Invalid JSON -> rejected:'
INSERT INTO event (id, payload) VALUES (99, '{broken');

SELECT * FROM event_user ORDER BY id;
-- MySQL's JSON type also normalizes the document:
SELECT payload FROM event WHERE id = 1;
-- Invalid JSON -> rejected:
INSERT INTO event (id, payload) VALUES (99, '{broken');

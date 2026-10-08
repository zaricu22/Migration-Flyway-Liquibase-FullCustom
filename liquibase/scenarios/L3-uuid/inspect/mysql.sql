-- char(36): the UUID is just TEXT. 36 characters instead of 16 bytes, and nothing validates it.
SELECT id, name FROM api_key ORDER BY id;
SELECT length(id) AS bytes_per_value FROM api_key LIMIT 1;
-- Invalid value -> ACCEPTED:
INSERT INTO api_key (id, name) VALUES ('not-a-uuid', 'garbage');
SELECT id, name FROM api_key WHERE name = 'garbage';

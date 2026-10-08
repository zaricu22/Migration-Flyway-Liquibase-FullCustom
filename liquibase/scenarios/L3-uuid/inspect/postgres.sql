\echo 'ORDER BY id (binary, left to right):'
SELECT id, name FROM api_key ORDER BY id;
SELECT pg_column_size(id) AS bytes_per_value FROM api_key LIMIT 1;
\echo 'Invalid value -> rejected by the type:'
INSERT INTO api_key (id, name) VALUES ('not-a-uuid', 'garbage');

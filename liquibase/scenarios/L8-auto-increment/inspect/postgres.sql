SELECT id, note FROM invoice ORDER BY id;
SELECT number, title FROM document;
\echo 'Explicit id 1003 is allowed (BY DEFAULT) but does NOT move the sequence...'
INSERT INTO invoice (id, note) VALUES (1003, 'explicit id');
\echo '...so the next generated id collides:'
INSERT INTO invoice (note) VALUES ('generated') RETURNING id;
\echo 'Fix: SELECT setval(pg_get_serial_sequence(''invoice'', ''id''), (SELECT max(id) FROM invoice));'

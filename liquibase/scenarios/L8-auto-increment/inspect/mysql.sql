SELECT id, note FROM invoice ORDER BY id;
-- Explicit id 1003 is allowed and AUTO_INCREMENT moves past it automatically:
INSERT INTO invoice (id, note) VALUES (1003, 'explicit id');
INSERT INTO invoice (note) VALUES ('generated');
SELECT LAST_INSERT_ID() AS last_generated_id;

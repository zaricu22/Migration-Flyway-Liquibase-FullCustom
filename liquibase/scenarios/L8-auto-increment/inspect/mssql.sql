SET NOCOUNT ON;
SELECT id, note FROM invoice ORDER BY id;
SELECT number, title FROM document;
-- Explicit id -> refused unless IDENTITY_INSERT is switched on for the table:
INSERT INTO invoice (id, note) VALUES (1003, 'explicit id');
SET IDENTITY_INSERT invoice ON;
INSERT INTO invoice (id, note) VALUES (1003, 'explicit id');
SET IDENTITY_INSERT invoice OFF;
-- ...and like MySQL (unlike PostgreSQL) the identity then continues after the highest value:
INSERT INTO invoice (note) OUTPUT inserted.id VALUES ('generated');

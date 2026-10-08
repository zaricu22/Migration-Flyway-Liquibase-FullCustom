-- person_naive lost its NOT NULL (MySQL, SQL Server) and DEFAULT (MySQL): NULL is accepted now.
INSERT INTO person_naive (id, last_name) VALUES (1, NULL);
INSERT INTO person (id, last_name) VALUES (1, NULL);
-- default still applied?
INSERT INTO person_naive (id) VALUES (2);
INSERT INTO person (id) VALUES (2);
SELECT 'person_naive' AS t, id, last_name FROM person_naive UNION ALL SELECT 'person', id, last_name FROM person ORDER BY 1, 2;

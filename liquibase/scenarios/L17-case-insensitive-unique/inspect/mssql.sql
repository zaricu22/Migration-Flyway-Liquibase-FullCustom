SET NOCOUNT ON;
INSERT INTO subscriber VALUES (1, 'ana@example.com');
INSERT INTO subscriber VALUES (2, 'jose@example.com');
INSERT INTO subscriber VALUES (3, 'ivan@example.com');
SELECT DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS db_collation;
-- Different case    -> rejected (_CI_)
INSERT INTO subscriber VALUES (10, 'ANA@Example.com');
-- Accent (é vs e)   -> accepted (_AS = accent-sensitive)
INSERT INTO subscriber VALUES (11, 'josé@example.com');
-- Trailing space    -> REJECTED: SQL Server ignores trailing spaces when comparing strings
INSERT INTO subscriber VALUES (12, 'ivan@example.com ');
-- Lookup: plain "=" is already case-insensitive
SELECT count(*) AS plain_equals FROM subscriber WHERE email = 'ANA@EXAMPLE.COM';

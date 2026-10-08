INSERT INTO subscriber VALUES (1, 'ana@example.com');
INSERT INTO subscriber VALUES (2, 'jose@example.com');
INSERT INTO subscriber VALUES (3, 'ivan@example.com');
\echo 'Different case    -> rejected (lower() index):'
INSERT INTO subscriber VALUES (10, 'ANA@Example.com');
\echo 'Accent (é vs e)   -> accepted (different value):'
INSERT INTO subscriber VALUES (11, 'josé@example.com');
\echo 'Trailing space    -> accepted (different value):'
INSERT INTO subscriber VALUES (12, 'ivan@example.com ');
\echo 'Lookup: a plain "=" is case-SENSITIVE -> 0 rows; you must query lower(email) = lower(?):'
SELECT count(*) AS plain_equals FROM subscriber WHERE email = 'ANA@EXAMPLE.COM';
SELECT count(*) AS lower_equals FROM subscriber WHERE lower(email) = lower('ANA@EXAMPLE.COM');

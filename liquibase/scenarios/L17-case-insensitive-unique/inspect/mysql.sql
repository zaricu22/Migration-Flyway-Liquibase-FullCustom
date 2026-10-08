INSERT INTO subscriber VALUES (1, 'ana@example.com');
INSERT INTO subscriber VALUES (2, 'jose@example.com');
INSERT INTO subscriber VALUES (3, 'ivan@example.com');
SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = DATABASE();
-- Different case    -> rejected (_ci)
INSERT INTO subscriber VALUES (10, 'ANA@Example.com');
-- Accent (é vs e)   -> REJECTED too: utf8mb4_0900_ai_ci is ACCENT-insensitive (_ai)
INSERT INTO subscriber VALUES (11, 'josé@example.com');
-- Trailing space    -> accepted: 0900 collations are NO PAD
INSERT INTO subscriber VALUES (12, 'ivan@example.com ');
-- Lookup: plain "=" is already case-insensitive
SELECT count(*) AS plain_equals FROM subscriber WHERE email = 'ANA@EXAMPLE.COM';

SELECT id, title, body, body_naive, body = body_naive AS naive_intact FROM article ORDER BY id;
-- The database default character set decides what "varchar" can store (utf8mb4 = full Unicode incl. emoji).
SELECT DEFAULT_CHARACTER_SET_NAME, DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = DATABASE();

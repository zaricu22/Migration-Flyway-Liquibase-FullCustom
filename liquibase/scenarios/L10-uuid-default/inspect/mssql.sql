SET NOCOUNT ON;
-- NEWID() -> version 4 (random)
SELECT id, user_name, SUBSTRING(CAST(id AS char(36)), 15, 1) AS uuid_version FROM session_token;
INSERT INTO session_token_sequential (user_name) VALUES ('a'), ('b'), ('c');
-- NEWSEQUENTIALID(): increasing in SQL Server's sort order (look at the FIRST group)
SELECT id, user_name FROM session_token_sequential ORDER BY id;

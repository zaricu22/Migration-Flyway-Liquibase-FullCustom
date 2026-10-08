-- 13th hex digit = UUID version. gen_random_uuid() -> version 4 (random)
SELECT id, user_name, substr(id::text, 15, 1) AS uuid_version FROM session_token;

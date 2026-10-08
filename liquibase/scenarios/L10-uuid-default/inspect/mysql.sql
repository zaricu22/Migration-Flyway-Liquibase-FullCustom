-- 13th hex digit = UUID version. MySQL UUID() -> version 1: time-based, and the last group is
-- derived from the server's MAC address / node id (same on every row, leaks host identity).
SELECT id, user_name, substr(id, 15, 1) AS uuid_version FROM session_token;

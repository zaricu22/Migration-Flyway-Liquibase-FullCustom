-- Run this while the migration is waiting to see who blocks whom.
SELECT pid, pg_blocking_pids(pid) AS blocked_by, wait_event_type, state, left(query, 60) AS query
FROM pg_stat_activity
WHERE datname = current_database() AND pid <> pg_backend_pid() AND state <> 'idle';

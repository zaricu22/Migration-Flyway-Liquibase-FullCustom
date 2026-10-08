-- Queries of the application. Unchanged before and after the switch: the table keeps its name.
-- The insert uses a timestamp inside the old range, so it also works between V2 and V5
-- (while the CHECK constraint is in place).
\echo '--- app: insert + read by time range'
INSERT INTO event (created_at, kind, payload) VALUES ('2026-06-30 18:00+00', 'buy', 'from app');
SELECT kind, count(*) FROM event
WHERE created_at >= '2026-06-01 00:00+00' AND created_at < '2026-07-01 00:00+00'
GROUP BY kind ORDER BY kind;

SET TIME ZONE 'UTC';
\echo 'Session time zone UTC:'
SELECT starts_at, starts_at_naive FROM meeting;
SET TIME ZONE 'America/New_York';
\echo 'Session time zone America/New_York (timestamptz follows the viewer, timestamp does not):'
SELECT starts_at, starts_at_naive FROM meeting;

-- Session time zone UTC (container default): the +02:00 literal was converted to UTC on insert.
SELECT @@session.time_zone AS session_tz, starts_at, starts_at_naive FROM meeting;
-- Another session time zone: TIMESTAMP is converted for display, DATETIME never is.
SET time_zone = '-04:00';
SELECT @@session.time_zone AS session_tz, starts_at, starts_at_naive FROM meeting;
SET time_zone = '+00:00';
-- TIMESTAMP ends on 2038-01-19:
INSERT INTO meeting (id, title, starts_at, starts_at_naive) VALUES (2, 'Far future', '2040-01-01 10:00:00', '2040-01-01 10:00:00');

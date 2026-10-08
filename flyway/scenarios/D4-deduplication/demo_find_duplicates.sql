-- Run after V1: how many duplicate groups exist, and what do they look like?
\echo '--- Duplicate groups by normalized email'
SELECT count(*) AS groups, sum(cnt) AS rows_in_groups, sum(cnt) - count(*) AS rows_to_remove
FROM (SELECT lower(trim(email)) AS k, count(*) AS cnt FROM customer GROUP BY 1 HAVING count(*) > 1) t;

\echo '--- One example group'
SELECT id, email, phone, created_at FROM customer
WHERE lower(trim(email)) = 'user1@example.com' ORDER BY created_at;

\echo '--- A unique index cannot be created yet'
\set ON_ERROR_STOP off
BEGIN;
CREATE UNIQUE INDEX customer_email_lower_uq ON customer (lower(trim(email)));
ROLLBACK;

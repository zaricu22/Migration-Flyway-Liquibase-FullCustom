-- PG12+: SET NOT NULL sees the validated CHECK (col IS NOT NULL) and skips the full-table scan.
-- The ACCESS EXCLUSIVE lock is held only for a moment.
-- client_min_messages = debug1 makes PostgreSQL say so:
--   "existing constraints on column ... are sufficient to prove that it does not contain nulls"
SET LOCAL lock_timeout = '5s';
SET LOCAL client_min_messages = debug1;

ALTER TABLE customer ALTER COLUMN country_code SET NOT NULL;

-- The CHECK is now redundant.
ALTER TABLE customer DROP CONSTRAINT customer_country_code_not_null;

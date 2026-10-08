-- Order matters: stop NEW NULLs first, then fix the old ones (V3).
-- If you backfill first, any NULL written between the backfill and the constraint makes
-- VALIDATE (V4) fail.
SET LOCAL lock_timeout = '5s';

-- 1. A default, so application inserts that omit the column get a value.
ALTER TABLE customer ALTER COLUMN country_code SET DEFAULT 'US';

-- 2. SET NOT NULL directly would scan the whole table under ACCESS EXCLUSIVE.
--    Instead: an equivalent CHECK, NOT VALID -> no scan, only a brief lock.
--    NEW writes with NULL are rejected from now on. Existing rows are not checked yet.
ALTER TABLE customer
    ADD CONSTRAINT customer_country_code_not_null CHECK (country_code IS NOT NULL) NOT VALID;

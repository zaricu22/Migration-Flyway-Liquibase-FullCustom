-- timestamp -> timestamptz. The critical part is the USING clause.
--
-- Without USING, PostgreSQL interprets the old values in the SESSION time zone. Flyway's session
-- runs in UTC here, so '12:00' Belgrade time would silently become 12:00 UTC: every row shifted
-- by 1-2 hours, differently in summer and winter. No error, and nobody notices for months.
--
-- USING ... AT TIME ZONE 'Europe/Belgrade' states what the values MEANT. DST is handled per row.
-- Ambiguous/nonexistent local times (the DST switch nights) are resolved by PostgreSQL's rules;
-- see verify.sql for what it chose.
--
-- This rewrites the table under ACCESS EXCLUSIVE. For big tables use expand/contract (B3).
ALTER TABLE orders
    ALTER COLUMN created_at TYPE timestamptz USING created_at AT TIME ZONE 'Europe/Belgrade';

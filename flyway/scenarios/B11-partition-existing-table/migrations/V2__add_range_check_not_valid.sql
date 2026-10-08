-- Step 1 of the zero-copy approach: the existing table will become the FIRST partition
-- ("everything before 2026-07-01"). ATTACH PARTITION has to prove that every row fits that range.
-- Without help it scans the whole table under a strong lock. A VALIDATED CHECK constraint that
-- implies the range lets PostgreSQL skip that scan.
--
-- NOT VALID: instant, only new rows are checked from now on (A6).
-- In real life choose a boundary AFTER the planned switch date: until the switch, the application
-- keeps inserting into this table, and rows above the boundary would be rejected.
SET LOCAL lock_timeout = '5s';

ALTER TABLE event
    ADD CONSTRAINT event_legacy_range CHECK (created_at < timestamptz '2026-07-01 00:00+00') NOT VALID; -- need for ATTACH

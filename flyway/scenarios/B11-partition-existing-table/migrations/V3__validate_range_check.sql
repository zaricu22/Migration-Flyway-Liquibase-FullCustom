-- Step 2: validate the existing rows. This scans the table, but only takes a
-- SHARE UPDATE EXCLUSIVE lock: reads and writes continue (A6).
-- It is slow but not blocking, we run it before the switch.
ALTER TABLE event VALIDATE CONSTRAINT event_legacy_range;   -- need for ATTACH

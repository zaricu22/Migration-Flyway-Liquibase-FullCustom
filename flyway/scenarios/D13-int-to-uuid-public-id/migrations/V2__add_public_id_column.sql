-- "ADD COLUMN public_id uuid NOT NULL DEFAULT gen_random_uuid()" in one statement would REWRITE
-- the table under ACCESS EXCLUSIVE (volatile default, see A3). Split it:
SET LOCAL lock_timeout = '5s';

ALTER TABLE customer ADD COLUMN public_id uuid;                                   -- instant
ALTER TABLE customer ALTER COLUMN public_id SET DEFAULT gen_random_uuid();        -- instant, NEW rows only

-- Existing rows stay NULL until the backfill (V3).

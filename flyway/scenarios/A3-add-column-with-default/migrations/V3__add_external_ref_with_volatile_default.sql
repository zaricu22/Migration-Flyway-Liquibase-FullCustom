-- Volatile default: every existing row needs its own value, so PostgreSQL rewrites the whole
-- table under an ACCESS EXCLUSIVE lock (no reads, no writes) for the entire duration.
-- On a large table this is an outage. Zero-downtime alternative (see D13):
--   1. ADD COLUMN external_ref uuid;                               -- instant
--   2. ALTER COLUMN external_ref SET DEFAULT gen_random_uuid();    -- instant, new rows only
--   3. backfill existing rows in batches (D2)
ALTER TABLE customer ADD COLUMN external_ref uuid NOT NULL DEFAULT gen_random_uuid();

INSERT INTO _demo_filenode VALUES ('3 after V3 (volatile default)', pg_relation_filenode('customer'));

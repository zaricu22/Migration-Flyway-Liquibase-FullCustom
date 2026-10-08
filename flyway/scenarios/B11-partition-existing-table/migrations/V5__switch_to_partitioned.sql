-- Step 4: the switch, in ONE short transaction. Nothing here reads or copies the 200,000 rows:
-- every step is a catalog change, thanks to the preparation in V2-V4.
-- The application keeps using the name "event" and doesn't notice the change.
SET LOCAL lock_timeout = '5s';

-- 4a. The old table's PK becomes (id, created_at), using the index from V4 (no scan, no rebuild).
--     Because of a PostgreSQL rule for partitioned tables: every PRIMARY KEY or UNIQUE constraint must include all columns of the partition key.
--     ATTACH can only reuse a child index for the parent's PK if the child index also backs a constraint.
ALTER TABLE event DROP CONSTRAINT event_pkey;
ALTER TABLE event ADD CONSTRAINT event_legacy_pkey PRIMARY KEY USING INDEX event_id_created_at_key; -- PREPARED index for PARTITION

-- 4b. Move the old table out of the way. Index names are unique per schema, so rename its index too.
ALTER TABLE event RENAME TO event_legacy;
ALTER INDEX event_created_at_idx RENAME TO event_legacy_created_at_idx;

-- 4c. The new partitioned table under the old name. Same columns, same sequence.
CREATE TABLE event (
    id         bigint NOT NULL DEFAULT nextval('event_id_seq'),
    created_at timestamptz NOT NULL,
    kind       text NOT NULL,
    payload    text,
    CONSTRAINT event_pkey PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);
CREATE INDEX event_created_at_idx ON event (created_at);

-- The sequence was owned by the old table: dropping event_legacy one day would drop it too.
ALTER SEQUENCE event_id_seq OWNED BY event.id;

-- 4d. The old table becomes the partition for everything before 2026-07-01.
--     The validated CHECK from V2/V3 proves the range -> no scan. Its matching indexes
--     (PK and created_at) are attached to the parent's indexes instead of being rebuilt.
ALTER TABLE event ATTACH PARTITION event_legacy     -- PREPARED check of range
    FOR VALUES FROM (MINVALUE) TO ('2026-07-01 00:00+00');

-- 4e. Monthly partitions for new data, plus a DEFAULT partition as a safety net.
CREATE TABLE event_2026_07 PARTITION OF event FOR VALUES FROM ('2026-07-01 00:00+00') TO ('2026-08-01 00:00+00');
CREATE TABLE event_2026_08 PARTITION OF event FOR VALUES FROM ('2026-08-01 00:00+00') TO ('2026-09-01 00:00+00');
CREATE TABLE event_2026_09 PARTITION OF event FOR VALUES FROM ('2026-09-01 00:00+00') TO ('2026-10-01 00:00+00');
CREATE TABLE event_2026_10 PARTITION OF event FOR VALUES FROM ('2026-10-01 00:00+00') TO ('2026-11-01 00:00+00');
CREATE TABLE event_2026_11 PARTITION OF event FOR VALUES FROM ('2026-11-01 00:00+00') TO ('2026-12-01 00:00+00');
CREATE TABLE event_2026_12 PARTITION OF event FOR VALUES FROM ('2026-12-01 00:00+00') TO ('2027-01-01 00:00+00');
CREATE TABLE event_default PARTITION OF event DEFAULT;

-- 4f. The helper constraint is redundant now (the partition bound enforces the range).
ALTER TABLE event_legacy DROP CONSTRAINT event_legacy_range;

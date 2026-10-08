-- After V5: new rows are routed to the monthly partitions, and queries read only the partitions they need.
\echo '--- Insert rows in different months: which partition did each one land in?'
INSERT INTO event (created_at, kind, payload) VALUES
    ('2026-06-15 10:00+00', 'view', 'demo'),
    ('2026-08-15 10:00+00', 'view', 'demo'),
    ('2027-03-01 10:00+00', 'view', 'demo')     -- no monthly partition yet -> DEFAULT
RETURNING id, created_at, tableoid::regclass AS partition;

\echo '--- Partition pruning: only event_2026_08 is scanned'
EXPLAIN (COSTS OFF)
SELECT count(*) FROM event WHERE created_at >= '2026-08-01 00:00+00' AND created_at < '2026-09-01 00:00+00';

\echo '--- Rows per partition'
SELECT tableoid::regclass AS partition, count(*) FROM event GROUP BY 1 ORDER BY 1;

\echo '--- The PK now includes the partition key: a unique key on id alone is not allowed'
DO $$
BEGIN
    ALTER TABLE event ADD CONSTRAINT event_id_only_uq UNIQUE (id);
    RAISE NOTICE 'unexpected: unique (id) was accepted';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'expected error: %', SQLERRM;
END $$;

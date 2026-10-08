\echo '--- Partitions of event'
SELECT c.relname AS partition, pg_get_expr(c.relpartbound, c.oid) AS bound
FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid
WHERE i.inhparent = 'event'::regclass ORDER BY c.relname;

DO $$
DECLARE
    rows_legacy bigint;
    part        regclass;
    new_id      bigint;
BEGIN
    IF (SELECT relkind FROM pg_class WHERE oid = 'event'::regclass) <> 'p' THEN
        RAISE EXCEPTION 'FAIL: event is not partitioned';
    END IF;
    IF NOT (SELECT relispartition FROM pg_class WHERE oid = 'event_legacy'::regclass) THEN
        RAISE EXCEPTION 'FAIL: the old table is not a partition of event';
    END IF;
    SELECT count(*) INTO rows_legacy FROM event_legacy;
    IF rows_legacy < 200000 THEN
        RAISE EXCEPTION 'FAIL: only % rows in the old partition, expected at least 200000', rows_legacy;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'event'::regclass AND contype = 'p') THEN
        RAISE EXCEPTION 'FAIL: no primary key on the partitioned table';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_index WHERE indrelid = 'event_legacy'::regclass AND NOT indisvalid) THEN
        RAISE EXCEPTION 'FAIL: invalid index on the old partition';
    END IF;

    -- a new row is routed to its monthly partition (then removed again)
    INSERT INTO event (created_at, kind) VALUES ('2026-08-15 10:00+00', 'verify')
    RETURNING id, tableoid::regclass INTO new_id, part;
    DELETE FROM event WHERE id = new_id;
    IF part <> 'event_2026_08'::regclass THEN
        RAISE EXCEPTION 'FAIL: August row landed in %', part;
    END IF;

    RAISE NOTICE 'OK: event is partitioned, % existing rows kept in place as partition event_legacy', rows_legacy;
END $$;

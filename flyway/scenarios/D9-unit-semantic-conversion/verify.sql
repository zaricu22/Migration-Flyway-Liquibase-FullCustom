SET TIME ZONE 'UTC';

\echo '--- The edge rows, shown in UTC and back in Belgrade time'
SELECT id,
       created_at                                       AS utc,
       created_at AT TIME ZONE 'Europe/Belgrade'        AS belgrade_local,
       price_cents
FROM orders WHERE id <= 5 ORDER BY id;

\echo '--- DST nights: ambiguous 02:30 (id 3) and nonexistent 02:30 (id 4). Check PostgreSQL''s choice is acceptable for you.'

DO $$
BEGIN
    IF (SELECT created_at FROM orders WHERE id = 1) <> timestamptz '2025-07-01 10:00:00+00' THEN
        RAISE EXCEPTION 'FAIL: summer time converted wrong';
    END IF;
    IF (SELECT created_at FROM orders WHERE id = 2) <> timestamptz '2025-01-15 11:00:00+00' THEN
        RAISE EXCEPTION 'FAIL: winter time converted wrong';
    END IF;
    RAISE NOTICE 'OK: local times converted with the correct offset (UTC+2 summer, UTC+1 winter)';

    IF (SELECT array_agg(price_cents ORDER BY id) FROM orders WHERE id <= 5) <> ARRAY[29, 57, 115, 435, 1999]::bigint[] THEN
        RAISE EXCEPTION 'FAIL: cents rounded wrong';
    END IF;
    RAISE NOTICE 'OK: 0.29 -> 29, 0.57 -> 57, 1.15 -> 115, 4.35 -> 435 cents (floor would give 28, 56, 114, 434)';
END $$;

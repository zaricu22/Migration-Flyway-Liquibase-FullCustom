\echo '--- Flyway history: versioned (V) and repeatable (R) migrations'
SELECT installed_rank, version, description, type, checksum FROM flyway_schema_history ORDER BY installed_rank;

\echo '--- Reference data'
SELECT * FROM country ORDER BY code;
SELECT * FROM order_status ORDER BY sort_order;

DO $$
BEGIN
    IF (SELECT count(*) FROM country) <> 4 THEN
        RAISE EXCEPTION 'FAIL: countries not seeded';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM order_status WHERE active) THEN
        RAISE EXCEPTION 'FAIL: order statuses not seeded';
    END IF;
    RAISE NOTICE 'OK: versioned and repeatable seeds applied';
END $$;

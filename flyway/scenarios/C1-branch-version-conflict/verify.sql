\echo '--- Migration history (installed_rank = order in which they really ran)'
SELECT installed_rank, version, description, success FROM flyway_schema_history ORDER BY installed_rank;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = current_schema() AND table_name = 'customer' AND column_name = 'phone') THEN
        RAISE EXCEPTION 'FAIL: V2 (phone, developer A) not applied';
    END IF;
    IF to_regclass('customer_email_uq') IS NULL THEN
        RAISE EXCEPTION 'FAIL: V3 (email index, developer B renumbered) not applied';
    END IF;
    IF (SELECT count(*) FROM flyway_schema_history WHERE NOT success) > 0 THEN
        RAISE EXCEPTION 'FAIL: failed migrations in the history';
    END IF;
    RAISE NOTICE 'OK: both branches applied, % migrations in the history',
        (SELECT count(*) FROM flyway_schema_history WHERE version IS NOT NULL);
END $$;

\echo '--- Converted edge cases'
SELECT * FROM payment WHERE id < 100 ORDER BY id;

\echo '--- Quarantine'
SELECT source_id, column_name, raw_value, error FROM payment_migration_error ORDER BY source_id, column_name;

DO $$
DECLARE
    legacy_ids   bigint;
    accounted    bigint;
BEGIN
    SELECT count(*) INTO legacy_ids FROM legacy_payment;
    SELECT count(*) INTO accounted FROM (
        SELECT id FROM payment
        UNION
        SELECT source_id FROM payment_migration_error
    ) t;
    IF accounted <> legacy_ids THEN
        RAISE EXCEPTION 'FAIL: % legacy rows neither converted nor quarantined', legacy_ids - accounted;
    END IF;
    IF EXISTS (SELECT 1 FROM payment p JOIN payment_migration_error e ON e.source_id = p.id) THEN
        RAISE EXCEPTION 'FAIL: a row is both converted and quarantined';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM payment_migration_error WHERE source_id = 4) THEN
        RAISE EXCEPTION 'FAIL: ''yesterday'' slipped through as a date';
    END IF;
    RAISE NOTICE 'OK: every legacy row is either converted (%) or quarantined (%)',
        (SELECT count(*) FROM payment), (SELECT count(DISTINCT source_id) FROM payment_migration_error);
END $$;

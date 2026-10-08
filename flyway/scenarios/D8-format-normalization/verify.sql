\echo '--- The hand-written edge cases'
SELECT id, email, full_name, phone, phone_raw FROM customer WHERE id <= 7 ORDER BY id;

\echo '--- Phones that could not be parsed (kept in phone_raw for manual review)'
SELECT count(*) AS unparseable FROM customer WHERE phone IS NULL AND phone_raw IS NOT NULL;

DO $$
BEGIN
    IF (SELECT email FROM customer WHERE id = 1) <> 'john.doe@example.com'
    OR (SELECT full_name FROM customer WHERE id = 1) <> 'John Doe'
    OR (SELECT phone FROM customer WHERE id = 1) <> '+15551234567'
    OR (SELECT phone FROM customer WHERE id = 3) <> '+442079460958'
    OR (SELECT phone FROM customer WHERE id = 4) <> '+15559876543'
    OR (SELECT phone FROM customer WHERE id = 5) IS NOT NULL THEN
        RAISE EXCEPTION 'FAIL: edge cases not normalized as expected';
    END IF;
    RAISE NOTICE 'OK: edge cases normalized';

    BEGIN
        INSERT INTO customer (email, full_name) VALUES ('New@Example.com', 'New User');
        RAISE EXCEPTION 'FAIL: non-canonical email accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: CHECK rejects non-canonical values from now on';
    END;
END $$;

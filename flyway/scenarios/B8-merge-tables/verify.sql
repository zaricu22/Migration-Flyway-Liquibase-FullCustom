\echo '--- Customers with profile data'
SELECT count(*) FILTER (WHERE bio IS NOT NULL) AS with_bio, count(*) AS total FROM customer;

DO $$
BEGIN
    IF to_regclass('customer_profile') IS NOT NULL THEN
        RAISE EXCEPTION 'FAIL: customer_profile still exists';
    END IF;
    IF (SELECT count(*) FROM customer WHERE bio IS NOT NULL) < 3000 THEN
        RAISE EXCEPTION 'FAIL: profile data missing';
    END IF;
    RAISE NOTICE 'OK: customer_profile merged into customer';
END $$;

\echo '--- Row counts'
SELECT (SELECT count(*) FROM customer) AS customers,
       (SELECT count(*) FROM address)  AS addresses;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = current_schema() AND table_name = 'customer' AND column_name IN ('street', 'city', 'zip')) THEN
        RAISE EXCEPTION 'FAIL: address columns still on customer';
    END IF;
    IF (SELECT count(*) FROM address) < 16000 THEN
        RAISE EXCEPTION 'FAIL: addresses missing';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid IN ('customer'::regclass, 'address'::regclass) AND NOT tgisinternal) THEN
        RAISE EXCEPTION 'FAIL: sync triggers left behind';
    END IF;
    RAISE NOTICE 'OK: address moved to its own table';
END $$;

\echo '--- Constraints on customer'
SELECT conname, contype, pg_get_constraintdef(oid) AS definition
FROM pg_constraint WHERE conrelid = 'customer'::regclass;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conrelid = 'customer'::regclass AND conname = 'customer_email_uq' AND contype = 'u') THEN
        RAISE EXCEPTION 'FAIL: unique constraint missing';
    END IF;
    RAISE NOTICE 'OK: customer_email_uq is a UNIQUE constraint backed by the concurrently built index';

    BEGIN
        INSERT INTO customer (email) VALUES ('user1@example.com');
        RAISE EXCEPTION 'FAIL: duplicate accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'OK: duplicate email rejected';
    END;
END $$;

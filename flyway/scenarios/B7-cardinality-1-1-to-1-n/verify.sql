\echo '--- Constraints and indexes on address'
SELECT indexname, indexdef FROM pg_indexes
WHERE schemaname = current_schema() AND tablename = 'address' ORDER BY indexname;

DO $$
BEGIN
    IF (SELECT pg_get_constraintdef(oid) FROM pg_constraint
        WHERE conrelid = 'address'::regclass AND contype = 'p') <> 'PRIMARY KEY (id)' THEN
        RAISE EXCEPTION 'FAIL: primary key is not address.id';
    END IF;
    RAISE NOTICE 'OK: address.id is the primary key';

    -- two non-primary addresses for the same customer: allowed
    INSERT INTO address (customer_id, street, city, is_primary) VALUES (3, 'x', 'x', false), (3, 'y', 'y', false);
    RAISE NOTICE 'OK: multiple addresses per customer allowed';

    BEGIN
        INSERT INTO address (customer_id, street, city, is_primary) VALUES (3, 'z', 'z', true);
        RAISE EXCEPTION 'FAIL: second primary address accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'OK: second primary address rejected by the partial unique index';
    END;

    DELETE FROM address WHERE customer_id = 3 AND NOT is_primary;
END $$;

\echo '--- Column types'
SELECT table_name, column_name, data_type, is_identity FROM information_schema.columns
WHERE table_schema = current_schema() AND (table_name, column_name) IN (('customer', 'id'), ('orders', 'customer_id'));

\echo '--- Constraints'
SELECT conrelid::regclass AS table_name, conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint WHERE conrelid IN ('customer'::regclass, 'orders'::regclass) ORDER BY 1, 2;

DO $$
DECLARE
    new_id bigint;
BEGIN
    IF (SELECT data_type FROM information_schema.columns WHERE table_schema = current_schema()
          AND table_name = 'customer' AND column_name = 'id') <> 'bigint'
    OR (SELECT data_type FROM information_schema.columns WHERE table_schema = current_schema()
          AND table_name = 'orders' AND column_name = 'customer_id') <> 'bigint' THEN
        RAISE EXCEPTION 'FAIL: columns are not bigint';
    END IF;
    RAISE NOTICE 'OK: customer.id and orders.customer_id are bigint';

    IF (SELECT data_type::text FROM pg_sequences
        WHERE schemaname = current_schema() AND sequencename = 'customer_id_seq') <> 'bigint' THEN
        RAISE EXCEPTION 'FAIL: identity sequence is not bigint';
    END IF;
    IF (SELECT last_value FROM pg_sequences
        WHERE schemaname = current_schema() AND sequencename = 'customer_id_seq') < 2147482600 THEN
        RAISE EXCEPTION 'FAIL: identity restarted from a lower value';
    END IF;
    RAISE NOTICE 'OK: identity sequence is bigint and continues from its old position';

    INSERT INTO customer (email) VALUES ('verify@example.com') RETURNING id INTO new_id;
    INSERT INTO orders (customer_id, amount) VALUES (new_id, 1);
    RAISE NOTICE 'OK: new customer % + order inserted', new_id;

    BEGIN
        INSERT INTO orders (customer_id, amount) VALUES (-1, 1);
        RAISE EXCEPTION 'FAIL: FK missing';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'OK: FK orders.customer_id -> customer.id enforced';
    END;
END $$;

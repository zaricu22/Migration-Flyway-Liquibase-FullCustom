\echo '--- Constraints on orders (convalidated = existing rows were checked)'
SELECT conname, contype, convalidated, pg_get_constraintdef(oid) AS definition
FROM pg_constraint WHERE conrelid = 'orders'::regclass AND contype IN ('f', 'c');

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint
               WHERE conrelid = 'orders'::regclass AND contype IN ('f', 'c') AND NOT convalidated) THEN
        RAISE EXCEPTION 'FAIL: a constraint is still NOT VALID';
    END IF;
    RAISE NOTICE 'OK: FK and CHECK are validated';
END $$;

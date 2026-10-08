\echo '--- Foreign keys on customer_note'
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'customer_note'::regclass AND contype = 'f';

\echo '--- Indexes on customer_note'
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'customer_note' AND schemaname = current_schema();

DO $$
BEGIN
    BEGIN
        INSERT INTO customer_note (customer_id, body) VALUES (-1, 'orphan');
        RAISE EXCEPTION 'FAIL: FK accepted an orphan row';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'OK: FK rejects orphan rows';
    END;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes
                   WHERE schemaname = current_schema() AND indexname = 'customer_note_customer_id_idx') THEN
        RAISE EXCEPTION 'FAIL: FK column is not indexed';
    END IF;
    RAISE NOTICE 'OK: FK column customer_note.customer_id is indexed';
END $$;

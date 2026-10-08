-- Batched backfill, COMMIT per batch (non-transactional, see .conf and D2).
DO $$
DECLARE
    batch_size constant bigint := 50000;
    from_id bigint := 0;
    max_id  bigint;
BEGIN
    SELECT coalesce(max(id), 0) INTO max_id FROM customer;
    WHILE from_id < max_id LOOP
        UPDATE customer SET public_id = gen_random_uuid()
        WHERE id > from_id AND id <= from_id + batch_size AND public_id IS NULL;
        from_id := from_id + batch_size;
        COMMIT;
    END LOOP;
END $$;

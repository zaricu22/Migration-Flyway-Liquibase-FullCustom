-- Non-transactional (see .conf): every batch commits on its own, so row locks are short
-- and the WAL/replication can keep up. Technique explained in D2.
-- Table is much smaller than 'orders' and do not need batch technique.
UPDATE customer SET id_new = id WHERE id_new IS NULL;

-- It copies customer_id into the new bigint column customer_id_new in small batches, each committed separately.
-- That way a large table is never locked for long, and a failure loses only the current batch.
DO $$
DECLARE
    batch_size constant bigint := 20000;
    from_id bigint := 0;
    max_id  bigint;
BEGIN
    SELECT coalesce(max(id), 0) INTO max_id FROM orders;
    WHILE from_id < max_id LOOP
        UPDATE orders SET customer_id_new = customer_id
        WHERE id > from_id AND id <= from_id + batch_size AND customer_id_new IS NULL;
        from_id := from_id + batch_size;
        COMMIT;
    END LOOP;
END $$;

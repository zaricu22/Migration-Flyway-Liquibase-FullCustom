-- Batched backfill. Non-transactional migration (see .conf) so COMMIT inside the DO block works.
--
-- Why not one "UPDATE orders SET order_number = ..."?
--   * one huge transaction: every updated row stays locked until the very end
--   * old row versions can't be vacuumed until it ends -> table/index bloat
--   * a burst of WAL -> replicas fall behind; a failure after 20 minutes rolls back everything
--
-- Batching rules:
--   * walk the primary key in RANGES (id > x AND id <= x + n): each batch is an index range scan.
--     Never use OFFSET/LIMIT: every next batch would re-scan everything before it.
--   * COMMIT after each batch: locks are released and vacuum can clean up behind us
--   * "AND order_number IS NULL": re-running after a crash skips work that's already done
--   * a short sleep between batches leaves room for regular traffic (throttling)
DO $$
DECLARE
    batch_size constant bigint := 25000;
    from_id bigint := 0;
    max_id  bigint;
    batches int := 0;
    updated bigint;
    total   bigint := 0;
BEGIN
    SELECT coalesce(max(id), 0) INTO max_id FROM orders;

    WHILE from_id < max_id LOOP
        UPDATE orders
        SET order_number = 'ORD-' || lpad(id::text, 10, '0')
        WHERE id > from_id AND id <= from_id + batch_size
          AND order_number IS NULL;

        GET DIAGNOSTICS updated = ROW_COUNT;
        total   := total + updated;
        from_id := from_id + batch_size;
        batches := batches + 1;

        COMMIT;

        IF batches % 5 = 0 THEN
            RAISE NOTICE 'batch %: up to id % of %, % rows updated so far', batches, from_id, max_id, total;
        END IF;
        PERFORM pg_sleep(0.01);
    END LOOP;

    RAISE NOTICE 'done: % rows in % batches', total, batches;
END $$;

-- Non-transactional (see .conf): COMMIT per batch.
--
-- One statement per batch moves parents AND children atomically with data-modifying CTEs:
-- DELETE ... RETURNING feeds INSERT. Rows are never "deleted but not yet archived".
-- FK checks run at the end of the statement, so deleting the items and their orders
-- in the same statement is fine.
--
-- The cutoff is fixed once at the start: with now() evaluated per batch, the boundary would move
-- while the job runs.
DO $$
DECLARE
    cutoff constant timestamptz := date_trunc('day', now() - interval '2 years');
    batch_size constant int := 5000;
    moved   int;
    total   bigint := 0;
BEGIN
    LOOP
        WITH batch AS (
            SELECT id FROM orders
            WHERE created_at < cutoff
            ORDER BY id
            LIMIT batch_size
            FOR UPDATE SKIP LOCKED        -- don't wait for rows the application is working on
        ),
        moved_items AS (
            DELETE FROM order_item i USING batch b
            WHERE i.order_id = b.id
            RETURNING i.*
        ),
        archived_items AS (
            INSERT INTO order_item_archive SELECT * FROM moved_items
        ),
        moved_orders AS (
            DELETE FROM orders o USING batch b
            WHERE o.id = b.id
            RETURNING o.*
        )
        INSERT INTO orders_archive SELECT * FROM moved_orders;

        GET DIAGNOSTICS moved = ROW_COUNT;
        COMMIT;

        total := total + moved;
        EXIT WHEN moved = 0;
    END LOOP;
    RAISE NOTICE 'archived % orders older than %', total, cutoff;
END $$;

-- Deleted rows leave dead tuples behind. Reclaim them for reuse and refresh planner statistics.
-- (VACUUM can't run inside a transaction, another reason this migration is non-transactional.
-- The disk space itself is only returned to the OS by VACUUM FULL / pg_repack.)
VACUUM (ANALYZE) orders;
VACUUM (ANALYZE) order_item;

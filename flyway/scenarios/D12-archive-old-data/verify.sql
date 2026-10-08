\echo '--- Hot vs archive'
SELECT 'orders' AS table_name, count(*), min(created_at)::date AS oldest, max(created_at)::date AS newest FROM orders
UNION ALL
SELECT 'orders_archive', count(*), min(created_at)::date, max(created_at)::date FROM orders_archive;

DO $$
DECLARE
    e _demo_expected%ROWTYPE;
BEGIN
    SELECT * INTO e FROM _demo_expected;

    IF (SELECT count(*) FROM orders) + (SELECT count(*) FROM orders_archive) <> e.orders
    OR (SELECT sum(total) FROM orders) + (SELECT sum(total) FROM orders_archive) <> e.order_total
    OR (SELECT count(*) FROM order_item) + (SELECT count(*) FROM order_item_archive) <> e.items THEN
        RAISE EXCEPTION 'FAIL: rows lost or duplicated between hot and archive tables';
    END IF;
    RAISE NOTICE 'OK: hot + archive = original (orders, totals, items)';

    IF EXISTS (SELECT 1 FROM orders WHERE created_at < date_trunc('day', now() - interval '2 years')) THEN
        RAISE EXCEPTION 'FAIL: old orders left in the hot table';
    END IF;
    IF EXISTS (SELECT 1 FROM order_item_archive i WHERE NOT EXISTS (SELECT 1 FROM orders_archive o WHERE o.id = i.order_id)) THEN
        RAISE EXCEPTION 'FAIL: archived items without their order';
    END IF;
    RAISE NOTICE 'OK: nothing older than 2 years in the hot table, archive is consistent';
END $$;

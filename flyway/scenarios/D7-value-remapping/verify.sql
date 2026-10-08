\echo '--- Status distribution'
SELECT status, count(*), count(refunded_at) AS with_refunded_at FROM orders GROUP BY status ORDER BY status;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM orders WHERE status IN (SELECT old_code FROM status_mapping)) THEN
        RAISE EXCEPTION 'FAIL: old codes left';
    END IF;
    IF EXISTS (SELECT 1 FROM orders WHERE status = 'cancelled' AND refunded_at IS NOT NULL)
    OR EXISTS (SELECT 1 FROM orders WHERE status = 'refunded'  AND refunded_at IS NULL) THEN
        RAISE EXCEPTION 'FAIL: conditional X -> cancelled/refunded rule broken';
    END IF;
    IF (SELECT count(*) FROM orders WHERE status = 'new') <> 40000 THEN
        RAISE EXCEPTION 'FAIL: N + PEND should give 40000 new orders';
    END IF;
    RAISE NOTICE 'OK: all codes remapped, many-to-one and conditional rules applied';
END $$;

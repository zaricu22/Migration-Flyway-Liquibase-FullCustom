\echo '--- Table file per step (same filenode = no rewrite)'
SELECT * FROM _demo_filenode ORDER BY step;

\echo '--- Columns of orders'
SELECT column_name, data_type, character_maximum_length, numeric_precision, numeric_scale
FROM information_schema.columns
WHERE table_schema = current_schema() AND table_name = 'orders' ORDER BY ordinal_position;

DO $$
BEGIN
    IF (SELECT count(DISTINCT filenode) FROM _demo_filenode) <> 1 THEN
        RAISE EXCEPTION 'FAIL: table was rewritten';
    END IF;
    RAISE NOTICE 'OK: no table rewrite in any step';

    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = current_schema() AND table_name = 'orders' AND column_name = 'amount') THEN
        RAISE EXCEPTION 'FAIL: amount still exists';
    END IF;
    RAISE NOTICE 'OK: float amount replaced by numeric(12,2) total_amount';
END $$;

\echo '--- Table file before/after the ALTER (same filenode = no rewrite)'
SELECT * FROM _demo_filenode ORDER BY step;

DO $$
BEGIN
    IF (SELECT count(DISTINCT filenode) FROM _demo_filenode) <> 1 THEN
        RAISE EXCEPTION 'FAIL: table was rewritten';
    END IF;
    RAISE NOTICE 'OK: ADD COLUMN (nullable, no default) did not rewrite the table';

    IF EXISTS (SELECT 1 FROM customer WHERE phone IS NOT NULL) THEN
        RAISE EXCEPTION 'FAIL: unexpected values in phone';
    END IF;
    RAISE NOTICE 'OK: all existing rows read phone as NULL';
END $$;

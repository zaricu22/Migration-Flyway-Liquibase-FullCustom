\echo '--- Edge cases after the split'
SELECT id, first_name, last_name FROM customer WHERE id <= 4 ORDER BY id;

DO $$
BEGIN
    IF (SELECT (first_name, last_name) FROM customer WHERE id = 2) IS DISTINCT FROM ('Mary Ann'::varchar, 'Evans'::varchar) THEN
        RAISE EXCEPTION 'FAIL: multi-word first name split wrong';
    END IF;
    IF (SELECT (first_name, last_name) FROM customer WHERE id = 3) IS DISTINCT FROM ('Cher'::varchar, NULL::varchar) THEN
        RAISE EXCEPTION 'FAIL: single-word name split wrong';
    END IF;
    IF (SELECT (first_name, last_name) FROM customer WHERE id = 4) IS DISTINCT FROM ('Alan'::varchar, 'Turing'::varchar) THEN
        RAISE EXCEPTION 'FAIL: whitespace not normalized';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = current_schema() AND table_name = 'customer' AND column_name = 'full_name') THEN
        RAISE EXCEPTION 'FAIL: full_name still exists';
    END IF;
    RAISE NOTICE 'OK: full_name split into first_name/last_name, edge cases handled';
END $$;

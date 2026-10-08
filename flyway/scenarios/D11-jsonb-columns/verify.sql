\echo '--- Edge cases'
SELECT id, newsletter, language, preferences, contact_extra FROM customer WHERE id <= 7 ORDER BY id;

\echo '--- Query on the packed JSON uses the GIN index'
SET enable_seqscan = off;
EXPLAIN (COSTS OFF) SELECT id FROM customer WHERE contact_extra @> '{"twitter": "@alice"}';
RESET enable_seqscan;

DO $$
BEGIN
    IF (SELECT array_agg(newsletter ORDER BY id) FROM customer WHERE id <= 7)
       <> ARRAY[true, true, true, false, false, false, false] THEN
        RAISE EXCEPTION 'FAIL: newsletter shapes converted wrong';
    END IF;
    IF (SELECT array_agg(coalesce(language::text, '-') ORDER BY id) FROM customer WHERE id <= 7)
       <> ARRAY['en', 'de', '-', 'fr', '-', '-', 'sr'] THEN
        RAISE EXCEPTION 'FAIL: language / legacy key "lang" converted wrong';
    END IF;
    IF EXISTS (SELECT 1 FROM customer WHERE preferences ?| ARRAY['newsletter', 'language', 'lang']) THEN
        RAISE EXCEPTION 'FAIL: extracted keys still in the JSON';
    END IF;
    IF (SELECT contact_extra FROM customer WHERE id = 2) <> '{"fax": "+49 30 1234"}'::jsonb THEN
        RAISE EXCEPTION 'FAIL: sparse columns packed wrong';
    END IF;
    RAISE NOTICE 'OK: JSON keys extracted to columns, sparse columns packed to JSON';
END $$;

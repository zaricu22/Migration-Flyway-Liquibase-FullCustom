\echo '--- Checkpoint'
SELECT * FROM migration_checkpoint;

\echo '--- Sample'
SELECT id, left(body, 30) AS body, word_count FROM document WHERE id IN (1, 39, 100) ORDER BY id;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM document WHERE word_count IS NULL) THEN
        RAISE EXCEPTION 'FAIL: rows without word_count';
    END IF;
    IF (SELECT finished_at FROM migration_checkpoint WHERE job = 'document.word_count') IS NULL THEN
        RAISE EXCEPTION 'FAIL: job not marked finished';
    END IF;
    IF (SELECT word_count FROM document WHERE id = 100) <> 0
    OR (SELECT word_count FROM document WHERE id = 39) <> 79 THEN
        RAISE EXCEPTION 'FAIL: word count wrong';
    END IF;
    RAISE NOTICE 'OK: all % documents processed, job finished', (SELECT count(*) FROM document);
END $$;

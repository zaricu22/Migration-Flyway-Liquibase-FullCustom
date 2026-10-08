-- Simulates a run that got interrupted after 5 batches (run after V2, before V3).
CALL backfill_word_count(20000, 5);

\echo '--- Checkpoint after the interrupted run'
SELECT job, last_id, finished_at FROM migration_checkpoint;

SELECT count(*) FILTER (WHERE word_count IS NOT NULL) AS done, count(*) AS total FROM document;

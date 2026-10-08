-- Non-transactional (see .conf): CALL of a procedure that COMMITs must not run inside a
-- transaction block. If this migration is interrupted, Flyway marks it as failed:
--   flyway repair   (removes the failed entry)   ->   flyway migrate   (resumes from the checkpoint)
CALL backfill_word_count(20000);

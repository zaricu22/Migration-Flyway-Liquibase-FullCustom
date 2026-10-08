ALTER TABLE document ADD COLUMN word_count integer;

-- Progress per job, persisted in the database.
CREATE TABLE migration_checkpoint (
    job         text        PRIMARY KEY,
    last_id     bigint      NOT NULL,
    started_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    finished_at timestamptz
);

-- The work lives in a procedure (procedures, unlike functions, can COMMIT):
--   * each batch and its checkpoint update commit TOGETHER -> the checkpoint never claims
--     work that was rolled back, and no batch is done twice
--   * on start it reads the checkpoint -> a re-run resumes after the last committed batch
--   * max_batches lets you run it in slices (and lets the demo simulate an interruption)
CREATE PROCEDURE backfill_word_count(batch_size int DEFAULT 20000, max_batches int DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE
    v_job constant text := 'document.word_count';
    v_last    bigint;
    v_max     bigint;
    v_batches int := 0;
BEGIN
    INSERT INTO migration_checkpoint (job, last_id) VALUES (v_job, 0) ON CONFLICT (job) DO NOTHING;
    SELECT last_id INTO v_last FROM migration_checkpoint WHERE job = v_job;
    SELECT coalesce(max(id), 0) INTO v_max FROM document;
    RAISE NOTICE 'job %: starting after id % (max id %)', v_job, v_last, v_max;
    COMMIT;

    WHILE v_last < v_max LOOP
        EXIT WHEN max_batches IS NOT NULL AND v_batches >= max_batches;

        UPDATE document
        SET word_count = CASE WHEN btrim(body) = '' THEN 0
                              ELSE array_length(regexp_split_to_array(btrim(body), '\s+'), 1) END
        WHERE id > v_last AND id <= v_last + batch_size;

        v_last := v_last + batch_size;
        UPDATE migration_checkpoint SET last_id = v_last, updated_at = now() WHERE job = v_job;
        COMMIT;                                   -- batch + checkpoint, atomically

        v_batches := v_batches + 1;
    END LOOP;

    IF v_last >= v_max THEN
        UPDATE migration_checkpoint SET finished_at = now() WHERE job = v_job;
        RAISE NOTICE 'job %: finished (% batches in this run)', v_job, v_batches;
    ELSE
        RAISE NOTICE 'job %: stopped after % batches at id %, run again to continue', v_job, v_batches, v_last;
    END IF;
    COMMIT;
END $$;

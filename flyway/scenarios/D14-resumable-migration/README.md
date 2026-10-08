# D14 — Resumable migration (checkpoint table)

**Goal:** a long data migration that can be interrupted at any point (deploy timeout, failover, Ctrl+C) and **continues where it stopped** when re-run.

| Version | What it does |
|---|---|
| V1 | 300,000 documents |
| V2 | `word_count` column, `migration_checkpoint` table, procedure `backfill_word_count(batch_size, max_batches)` |
| V3 | Non-transactional `CALL backfill_word_count(20000)` |

**How it works**
- The procedure reads `last_id` from the checkpoint on start and processes key ranges after it.
- **Each batch and its checkpoint update commit together.** After a crash, the checkpoint points exactly at the last committed batch: no batch is lost and none is done twice.
- `finished_at` marks completion, and `updated_at` shows whether the job is still moving.
- A **procedure** instead of a `DO` block (**D2**) means the same code can also run by hand in slices, `CALL backfill_word_count(20000, 10)`, outside Flyway, for example in a quiet hour.

**When V3 is interrupted**
A non-transactional migration that fails is recorded as **failed** in `flyway_schema_history`, and Flyway refuses to continue until you run `flyway repair`. Then `migrate` runs V3 again and the procedure resumes from the checkpoint.

**Run the interruption demo**
```bash
./run.sh D14 clean && ./run.sh D14 migrate 2
./run.sh D14 sql demo_interrupted_run.sql   # stops after 5 batches: 100,000 of 300,000 done
./run.sh D14 migrate                         # "starting after id 100000": resumes, doesn't restart
./run.sh D14 verify
```

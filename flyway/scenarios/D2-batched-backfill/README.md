# D2 — Batched backfill of a large table

**Goal:** fill a new column for 500,000 existing rows without one huge transaction.

| Version | What it does |
|---|---|
| V1 | `orders` with 500,000 rows |
| V2 | Add nullable `order_number` + `BEFORE INSERT` trigger for **new** rows |
| V3 | Non-transactional `DO` block: update in primary-key ranges of 25,000, `COMMIT` after each batch |

**Why not a single `UPDATE`?**
- Every updated row stays locked until the very end.
- Old row versions can't be vacuumed during the transaction, which bloats the table and indexes.
- The WAL burst makes replicas lag.
- A failure at 95% rolls back everything.

**Batching rules used here**
- **Key ranges** (`id > x AND id <= x + n`), never `OFFSET`/`LIMIT`, which re-scans everything before the offset on each batch.
- **`COMMIT` per batch.** Needs a non-transactional migration (`executeInTransaction=false` in `.conf`). PG11+ allows `COMMIT` in `DO` blocks and procedures when they aren't called inside an outer transaction.
- **Idempotent filter** (`AND order_number IS NULL`): a re-run after a crash skips finished work. **D14** adds an explicit checkpoint.
- **Throttle** with `pg_sleep` between batches to leave room for regular traffic.
- **New rows are handled separately** (a trigger or the application), so the backfill has a fixed end.

**Caveat:** a non-transactional migration that fails halfway leaves committed batches behind, and Flyway records the migration as failed. Fix the cause, run `flyway repair`, and migrate again. The idempotent filter makes the re-run safe.

**Run**
```bash
./run.sh D2 all                           # progress NOTICEs every 5 batches
./run.sh D2 sql demo_progress.sql         # in a 2nd terminal during V3
```

# D12 — Archive / move old data

**Goal:** move orders older than 2 years, **with their items**, from the hot tables into archive tables. Do it in batches, without locking the hot tables for long and without losing or duplicating a row.

| Version | What it does |
|---|---|
| V1 | 250,000 orders over ~4.75 years, 2 items each |
| V2 | `orders_archive` / `order_item_archive` via `CREATE TABLE ... (LIKE ...)` + PK/FK |
| V3 | Non-transactional loop: one statement per batch moves items + orders (`DELETE ... RETURNING` → `INSERT`), `COMMIT` per batch, then `VACUUM (ANALYZE)` |

**Key points**
- **Data-modifying CTEs** delete from the hot table and insert into the archive **in one statement**. A row is never "deleted but not archived", even if the job is killed.
- Parents and children move together, and FK checks run at the end of the statement.
- **`FOR UPDATE SKIP LOCKED`** skips rows the application is currently locking instead of waiting for them. They get picked up by a later batch.
- **Fixed cutoff:** computed once at the start. With `now()` evaluated per batch, the boundary moves while the job runs.
- **`LIKE`** keeps the same column order, so `SELECT *` / `RETURNING *` line up. It doesn't copy identity, indexes or FKs, so add those explicitly.
- **After deleting:** `VACUUM (ANALYZE)` makes the space reusable and refreshes statistics. The OS only gets the disk space back with `VACUUM FULL` / `pg_repack`.
- For recurring archiving on very large tables, **range partitioning** by `created_at` is the long-term fix: detaching a partition is instant.

**Run**
```bash
./run.sh D12 all
```

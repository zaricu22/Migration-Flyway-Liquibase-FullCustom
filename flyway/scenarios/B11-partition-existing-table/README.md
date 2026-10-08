# B11 — Partition an existing large table

**Goal:** turn a big, ever-growing table into a `RANGE`-partitioned table (by month), **without copying the existing rows** and with only a short lock.

> **Not yet run against the containers.** The behavior below is expected from the PostgreSQL 17 documentation; run the commands to confirm it.

PostgreSQL can't convert a table into a partitioned one in place. The usual alternative, a new partitioned table plus a batched copy with dual writes, moves every row. The **zero-copy approach** used here makes the existing table the **first partition** of a new parent instead.

| Version | Step | Lock / cost |
|---|---|---|
| V1 | `event` with 200,000 rows (Jan–Jun 2026), PK `id` | — |
| V2 | `CHECK (created_at < '2026-07-01') NOT VALID` | instant |
| V3 | `VALIDATE CONSTRAINT` | scans, but reads and writes continue |
| V4 | `CREATE UNIQUE INDEX CONCURRENTLY (id, created_at)` (non-transactional, `.conf`) | builds, writes continue |
| V5 | PK swap `USING INDEX`, rename to `event_legacy`, new partitioned `event`, `ATTACH PARTITION event_legacy FOR VALUES FROM (MINVALUE) TO ('2026-07-01')`, monthly + default partitions | one short transaction, **catalog changes only** |
| V6 | `ANALYZE event` | statistics for the parent |

**Key points**
- **The validated CHECK is what makes it fast.** `ATTACH PARTITION` must prove that every row fits the partition's range. If a valid `CHECK` constraint already implies it, PostgreSQL skips the full-table scan it would otherwise run under an exclusive lock.
- **Every PK / UNIQUE constraint on a partitioned table must include the partition key.** The PK becomes `(id, created_at)`. Uniqueness of `id` alone can no longer be enforced by the database (the sequence still guarantees it in practice). The same applies to **foreign keys referencing the table**: they need both columns, so referencing tables need a `created_at` column too. That is often the hardest part of a real partitioning project.
- **Prepare matching indexes beforehand.** On attach, an existing equivalent index on the partition is attached to the parent's index instead of being rebuilt. For the parent's PK, the partition's index has to back a constraint too, hence the PK swap `USING INDEX` (as in **B7**, **B9**).
- **The boundary must be in the future of the switch.** Between V2 and V5, the CHECK rejects rows above the boundary. In real life, pick the first day of a month *after* the planned switch, and create the monthly partitions from there.
- **The sequence moves to the new table** (`OWNED BY event.id`). Otherwise dropping `event_legacy` one day would drop the sequence too.
- **The `DEFAULT` partition is a safety net with a cost.** Rows without a matching partition land there instead of failing. Creating a new monthly partition later checks the default partition for rows of that range, so keep it empty: create partitions ahead of time (a scheduled job, or the `pg_partman` extension).
- **Autovacuum never analyzes the partitioned parent.** Run `ANALYZE event` after the switch and after big loads (V6).
- **The application doesn't change:** the table keeps its name (`app.sql` runs before and after). Queries that filter on `created_at` read only the matching partitions (partition pruning, `demo_after_switch.sql`).
- **Later:** the old data can stay as one big partition, be detached and archived (`DETACH PARTITION ... CONCURRENTLY`), or be split into months in batches.

**Run step by step**
```bash
./run.sh B11 clean
./run.sh B11 migrate 4 && ./run.sh B11 sql app.sql          # still a plain table, app works
./run.sh B11 migrate   && ./run.sh B11 sql app.sql          # partitioned, same app queries work
./run.sh B11 sql demo_after_switch.sql                      # routing, pruning, the PK rule
./run.sh B11 verify
```

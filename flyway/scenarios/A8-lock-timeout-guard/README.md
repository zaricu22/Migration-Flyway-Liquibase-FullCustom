# A8 — `lock_timeout` guard

**Goal:** stop a quick DDL from turning into an outage when it can't get its lock.

| Version | What it does |
|---|---|
| V1 | `customer` table |
| V2 | `SET LOCAL lock_timeout = '3s'`, then `ALTER TABLE ... ADD COLUMN` |

**The problem: the lock queue**
1. A long report runs `SELECT ...` on `customer` (holds `ACCESS SHARE`).
2. The migration's `ALTER TABLE` needs `ACCESS EXCLUSIVE`, so it waits.
3. Every **new** `SELECT`/`INSERT` on `customer` now queues **behind the ALTER**, and the table is effectively down until the report finishes.

With `lock_timeout`, step 2 gives up after 3 seconds. The migration fails, the queue drains, and you retry later. On PostgreSQL the failed migration rolls back completely, so a plain re-run is enough.

**Key points**
- Use `SET LOCAL` so the setting is scoped to the migration's transaction. A plain `SET` leaks into every following migration on Flyway's connection.
- `statement_timeout` is a second guard that caps the runtime of the statement itself.
- Use both for any DDL on a busy table: `ADD COLUMN`, `ADD CONSTRAINT`, `DROP`, `RENAME`...

**Run the demo** (two terminals)
```bash
./run.sh A8 clean && ./run.sh A8 migrate 1

# terminal 1: a long-running report holds a lock for 20s
./run.sh A8 sql demo_hold_lock.sql

# terminal 2, within those 20s: fails after ~3s with "canceling statement due to lock timeout"
./run.sh A8 migrate
./run.sh A8 sql demo_show_blocking.sql   # optional: who blocks whom

# after the lock is released: retry succeeds
./run.sh A8 migrate && ./run.sh A8 verify
```

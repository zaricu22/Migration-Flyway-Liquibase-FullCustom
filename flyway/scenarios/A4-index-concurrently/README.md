# A4 — Create an index `CONCURRENTLY`

**Goal:** add an index to a live table without blocking writes, and handle the failure mode that leaves an `INVALID` index.

| Version | What it does |
|---|---|
| V1 | `orders` with 300,000 rows |
| V2 | `DROP INDEX CONCURRENTLY IF EXISTS` + `CREATE INDEX CONCURRENTLY` (non-transactional) |

**Key points**
- A plain `CREATE INDEX` blocks every `INSERT`/`UPDATE`/`DELETE` until the build finishes. `CONCURRENTLY` doesn't, but it takes longer and **cannot run inside a transaction**.
- Flyway runs each migration in a transaction by default. The script config file `V2__create_index_concurrently.sql.conf` (`executeInTransaction=false`) turns that off for this one migration.
- A non-transactional migration can't mix in transactional statements, so keep it to the index statements only.
- `docker-compose.yml` sets `FLYWAY_POSTGRESQL_TRANSACTIONAL_LOCK=false`. Flyway's default lock keeps a transaction open during the run, and `CREATE INDEX CONCURRENTLY` waits for all open transactions, so it would wait for Flyway itself and hang.
- A failed concurrent build leaves an **INVALID** index: writes maintain it, but queries never use it. `CREATE INDEX CONCURRENTLY IF NOT EXISTS` would silently keep the broken one. Dropping any leftover first makes the migration re-runnable.

**Run**
```bash
./run.sh A4 all
./run.sh A4 sql demo_invalid_index.sql   # see a failed build leave an INVALID index
```

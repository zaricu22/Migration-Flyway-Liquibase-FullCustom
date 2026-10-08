# L19 — Transactional DDL

**Conflict:** Liquibase runs each changeset in a transaction. Whether that transaction can **undo DDL** depends on the engine.

| | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| `CREATE/ALTER/DROP` inside a transaction | transactional | **implicit COMMIT** before and after each DDL | transactional |
| Changeset fails at its 2nd DDL | everything rolled back | **1st DDL stays**, changeset not recorded | everything rolled back |
| Re-running the changeset | works | ❌ *Table 'ledger' already exists*, stuck | works |

**Failure demo** (`failure-demo.yaml`: two `createTable` in one changeset, the second has a FK to a missing table):
```
postgres  update FAILED  -> tables left: (none)
mssql     update FAILED  -> tables left: (none)
mysql     update FAILED  -> tables left: ledger          <- half-applied, not in DATABASECHANGELOG
mysql     rerun          -> ERROR: Table 'ledger' already exists   <- stuck until fixed by hand
```

**The portable pattern** (`changelog.yaml`)
1. **One DDL statement per changeset.** A failure then leaves the database exactly at a changeset boundary on every engine.
2. **Preconditions for re-runnability:** `not tableExists` + `onFail: MARK_RAN`. If the object already exists (from a half-failed run or a manual fix), the changeset is recorded as `MARK_RAN` and Liquibase moves on.
3. DML (`insert`, `update`) can be grouped. It's transactional everywhere.

Running the good changelog on the stuck MySQL database recovers it:
```
1-create-ledger        MARK_RAN     <- ledger already existed
2-create-ledger-entry  EXECUTED
3-seed-ledger          EXECUTED
```

**Also:** some statements can't run inside a transaction at all (PostgreSQL `CREATE INDEX CONCURRENTLY`, `ALTER TYPE ... ADD VALUE` before PG12, `VACUUM`). Use `runInTransaction: false` on those changesets. It's the Liquibase equivalent of Flyway's `executeInTransaction=false` (Flyway **A4**).

**Run**
```bash
CHANGELOG=failure-demo ./run.sh L19                 # see what each engine leaves behind
CHANGELOG=failure-demo ./run.sh L19 mysql yaml rerun  # MySQL is stuck
./run.sh L19 mysql yaml rerun                        # the good changelog recovers it (MARK_RAN)
./run.sh L19                                         # the good changelog on fresh databases
```

# L23 — SQL Server: unique with NULLs, and multiple cascade paths

**Conflict:** two SQL Server rules that break changelogs which work fine on PostgreSQL and MySQL.

> **Not yet run against the containers.** The results below are the expected behavior; run the commands to confirm them.

## 1. A unique column that may be NULL

| | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| `UNIQUE (tax_number)`, two rows with NULL | ✅ allowed (NULLs are never equal) | ✅ allowed | ❌ *Violation of UNIQUE KEY constraint ... The duplicate key value is (&lt;NULL&gt;).* |
| Fix | — | — | **filtered unique index** `WHERE tax_number IS NOT NULL` |

Typical case: an optional business key (tax number, external id, e-mail for guests) that must be unique **when present**.

The portable changelog uses `dbms`:
- `postgresql, mysql`: `addUniqueConstraint`.
- `mssql`: `CREATE UNIQUE INDEX ... WHERE tax_number IS NOT NULL` as raw SQL, because `createIndex` has no `WHERE` clause (same as **L16**). A raw SQL changeset needs its own rollback block (**L22**).

The opposite rule exists too: PostgreSQL 15+ can treat NULLs as equal with `UNIQUE NULLS NOT DISTINCT`, if that's what the model needs.

## 2. Multiple cascade paths

```
department ──CASCADE──> employee ──CASCADE──> assignment
department ──CASCADE──> project  ──CASCADE──> assignment     <- second path to assignment
```

| | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| Second cascading FK to `assignment` | ✅ | ✅ | ❌ *Introducing FOREIGN KEY constraint 'fk_assignment_project' on table 'assignment' may cause cycles or multiple cascade paths.* |

SQL Server refuses any schema where one delete could reach the same table along two cascade paths (or in a cycle), even if the data would never conflict.

**The portable pattern:** keep **one** cascade path and make the other `NO ACTION`, **on all engines**, so a delete behaves the same everywhere. Deleting a project then means: delete its assignments first, then the project (in the application or a stored procedure). The scenario inspect shows it: deleting an employee cascades to its assignments; deleting a project with assignments is rejected until they are removed.

Other options, and why they're second choice:
- `dbms`-specific FKs (`CASCADE` on PostgreSQL and MySQL, `NO ACTION` on SQL Server) make the same delete succeed on one engine and fail on another.
- Triggers instead of the second cascade are awkward on SQL Server: an `INSTEAD OF DELETE` trigger is not allowed on a table that has a cascading FK of its own (`project` → `department` here).

## Run

```bash
CHANGELOG=failure-unique-null ./run.sh L23    # fails only on SQL Server (second NULL)
CHANGELOG=failure-cascade ./run.sh L23        # fails only on SQL Server (fk_assignment_project)
./run.sh L23                                  # the portable pattern on all three engines
```
The inspect scripts of this scenario expect the tables of the portable changelog; after a failure demo they show errors for the missing tables.

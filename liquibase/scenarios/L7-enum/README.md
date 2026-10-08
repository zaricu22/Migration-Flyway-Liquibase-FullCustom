# L7 — Enum

**Conflict:** three completely different models for "a column with a fixed list of values". Adding a value later is a different statement on every engine, and even `ORDER BY` behaves differently.

| | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| Model | named type `CREATE TYPE ... AS ENUM` | inline column type `ENUM(...)` | none → `varchar` + `CHECK` |
| Add a value | `ALTER TYPE ... ADD VALUE` | `MODIFY` the **whole column** (all values + `NOT NULL` + default) | drop and re-create the `CHECK` |
| Invalid value | ❌ `invalid input value for enum` | ❌ `Data truncated` (strict mode only!) | ❌ CHECK violation |
| `ORDER BY status` | declaration order | declaration order | **alphabetical** |
| Remove a value | not supported | `MODIFY` (fails if rows use it) | re-create the `CHECK` |

```
ORDER BY status   postgres / mysql: new, paid, shipped, cancelled
                  mssql:            cancelled, new, paid, shipped
```

**Liquibase solution**
- A **property** `status_type` (`order_status` / `ENUM('new', ...)` / `varchar(20)`) so there's one `createTable` for all engines.
- **`dbms`-specific changesets** for the parts only one engine needs: `CREATE TYPE` (PostgreSQL) and the `CHECK` (SQL Server).
- Adding a value = **three changesets with the same purpose**, one per `dbms`.
- The new value is used in a **separate changeset**. On PostgreSQL, a new enum value can't be used in the transaction that added it (see Flyway **A7**).

**Traps**
- **MySQL `MODIFY` redefines the column.** Forgetting `NOT NULL DEFAULT 'new'` makes the column nullable and removes the default (see **L14**).
- **MySQL outside strict mode** stores invalid enum values as `''` with only a warning.
- Code that sorts by status gives different results on SQL Server. If the order matters, add an explicit `sort_order` (or use a lookup table, which is portable everywhere).

**Run**
```bash
./run.sh L7
```

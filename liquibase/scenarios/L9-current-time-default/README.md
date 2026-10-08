# L9 — Current-time defaults

**Conflict:** "default = now" has different function names, precision rules and syntax per engine. "Update this column on every change" is built into only one engine.

| `defaultValueComputed` | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| `CURRENT_TIMESTAMP` (portable ✅) | `now()` | `CURRENT_TIMESTAMP` | `getdate()` |
| `NOW()` | ✅ | ✅ | ❌ passed through untranslated → error |
| `CURRENT_DATE` | ✅ | ❌ expression defaults need `(CURRENT_DATE)` | ❌ unknown in SQL Server 2022 |
| on `datetime(6)` | — | ❌ `NOW()` without `(6)` → *Invalid default value* | — |

Recommended properties:

| Property | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| `ts6_type` | `timestamp(6)` | `datetime(6)` | `datetime2(6)` |
| `now6` | `CURRENT_TIMESTAMP` | `CURRENT_TIMESTAMP(6)` | `SYSDATETIME()` |
| `today` | `CURRENT_DATE` | `(CURRENT_DATE)` | `CAST(GETDATE() AS date)` |

**Precision** of the "portable" `timestamp` + `CURRENT_TIMESTAMP` column:
```
postgres  2026-09-24 16:51:59.159738     microseconds
mysql     2026-09-24 16:52:04            whole seconds (TIMESTAMP without fsp)
mssql     2026-09-24 16:52:10.3866667    GETDATE() ticks in 3.33 ms steps
```

**Auto-update `updated_at`**
| PostgreSQL | MySQL | SQL Server |
|---|---|---|
| `BEFORE UPDATE` trigger + function | `ON UPDATE CURRENT_TIMESTAMP(6)` (column option) | `AFTER UPDATE` trigger joining `inserted` |

**Liquibase notes**
- **`splitStatements: false`** for procedural code. Liquibase splits `sql` on `;` by default, which cuts a PL/pgSQL or T-SQL body into invalid pieces.
- SQL Server requires `CREATE TRIGGER` to be the **only statement in its batch**, so give it its own `sql` change.
- PostgreSQL `now()` is the **transaction start time**. Every row inserted in one transaction gets the same value. Use `clock_timestamp()` when you need the actual time (as the trigger here does).

**Run**
```bash
./run.sh L9      # inserts a row, waits 1.2 s, updates it: updated_at moves on all engines
```

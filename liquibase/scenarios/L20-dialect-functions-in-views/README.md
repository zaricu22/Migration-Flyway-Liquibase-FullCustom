# L20 — Dialect functions in views

**Conflict:** views are raw SQL, so every dialect difference in functions and syntax shows up there. Some differences raise errors. The dangerous ones silently return different results.

| Task | PostgreSQL | MySQL | SQL Server | Portable? |
|---|---|---|---|---|
| Concatenate | `\|\|`, `concat()` | `CONCAT()` (`\|\|` = **logical OR**) | `+`, `CONCAT()` | `CONCAT_WS` ✅ |
| `CONCAT('Cher', ' ', NULL)` | `'Cher '` | **`NULL`** | `'Cher '` | ❌ |
| `CONCAT_WS(' ', 'Cher', NULL)` | `'Cher'` | `'Cher'` | `'Cher'` | ✅ |
| `'a' \|\| 'b'` | `'ab'` | **`0`** (no error!) | syntax error | ❌ |
| Now − 30 days | `now() - interval '30 days'` | `NOW() - INTERVAL 30 DAY` | `DATEADD(day, -30, GETDATE())` | ❌ |
| First N rows | `LIMIT n` | `LIMIT n` | `TOP n` | ❌ |
| `CURRENT_TIMESTAMP` | ✅ | ✅ | ✅ | ✅ |

**Liquibase solution**
- **Write portable SQL where it exists** (`CONCAT_WS`, `CURRENT_TIMESTAMP`, `COALESCE`, `CASE`). `customer_display` is **one** view for all engines.
- **One `createView` per engine** (`dbms`) where no portable form exists: `recent_customer` (date arithmetic) and `oldest_customers` (row limit).
- **`runOnChange: true` + `replaceIfExists: true`** make view changesets *repeatable*, like Flyway `R__` migrations. Edit the SQL, run `update`, and Liquibase re-applies only that changeset with `CREATE OR REPLACE VIEW` (PostgreSQL, MySQL) or `CREATE OR ALTER VIEW` (SQL Server).

**Watch out**
- `ORDER BY` inside a view isn't a guarantee: SQL Server only allows it together with `TOP`, and callers should order their own queries.
- MySQL's `||` is deprecated as OR but still active unless `sql_mode` contains `PIPES_AS_CONCAT`. The result is `0` or `1` with a warning, never an error.

**Run**
```bash
./run.sh L20
# edit the customer_display view in changelog.yaml, then (no reset) re-apply only that changeset:
./run.sh L20 all yaml rerun
```

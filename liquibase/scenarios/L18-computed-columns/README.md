# L18 — Generated / computed columns

**Conflict:** all three engines support columns computed from other columns, with different syntax, different rules for the expression, and different defaults for stored vs virtual.

| | PostgreSQL 17 | MySQL | SQL Server |
|---|---|---|---|
| Syntax | `<type> GENERATED ALWAYS AS (expr) STORED` | `<type> GENERATED ALWAYS AS (expr) [VIRTUAL\|STORED]` | `AS (expr) [PERSISTED]` (**no type**, inferred) |
| Stored | `STORED` (only option) | `STORED` | `PERSISTED` |
| Virtual (computed on read) | ❌ (PostgreSQL 18+) | `VIRTUAL` (default) | default (non-persisted) |
| Expression rules | **must be IMMUTABLE** | deterministic built-ins | deterministic for `PERSISTED` / indexing |
| Writing the column | ❌ *can only be updated to DEFAULT* | ❌ error 3105 | ❌ error 271 |
| Liquibase change type | none → raw `sql` | | |

**Traps shown here**
- **PostgreSQL `concat()` is not immutable** (only `STABLE`), so `GENERATED ALWAYS AS (concat(sku, ' x ', qty))` fails with *generation expression is not immutable*. Use `sku || ' x ' || qty::text`. MySQL and SQL Server accept `CONCAT()`.
- **SQL Server infers the type**: `CONCAT(sku, ' x ', qty)` became `varchar(35) NOT NULL`. Wrap the expression in `CAST(... AS ...)` if you need a specific type (done for `line_total`).
- **SQL Server `PERSISTED` columns** need `QUOTED_IDENTIFIER ON` in writing sessions, like filtered indexes (**L16**).
- Inserts must **not** list computed columns, and neither can `INSERT ... VALUES` without a column list on MySQL.

**Liquibase solution:** the PostgreSQL and MySQL syntax is close enough to share one changeset (`dbms: postgresql, mysql`) for a numeric expression. Text expressions and SQL Server each need their own variant.

**Run**
```bash
./run.sh L18
```

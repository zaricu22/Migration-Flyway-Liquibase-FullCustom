# L14 — Rename / modify a column

**Conflict:** "rename a column" and "widen a column" are one-liners in Liquibase, but the SQL behind them differs. On MySQL and SQL Server that SQL can **silently drop** `NOT NULL` and `DEFAULT`.

Generated SQL (`./run.sh L14 <engine> yaml sql`):
```sql
-- postgresql
ALTER TABLE person_naive RENAME COLUMN surname TO last_name;
ALTER TABLE person_naive ALTER COLUMN last_name TYPE VARCHAR(100) USING (last_name::VARCHAR(100));
-- mysql  (CHANGE / MODIFY = redefine the WHOLE column from what's written here)
ALTER TABLE person_naive CHANGE surname last_name VARCHAR(50);
ALTER TABLE person_naive MODIFY last_name VARCHAR(100);
-- mssql
exec sp_rename 'person_naive.surname', 'last_name', 'COLUMN';
ALTER TABLE person_naive ALTER COLUMN last_name varchar(100);
```

Result on `person_naive` (started as `varchar(50) NOT NULL DEFAULT 'unknown'`):

| | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| `NOT NULL` | ✅ kept | ❌ **lost** (already by the rename) | ❌ **lost** (`ALTER COLUMN` without `NOT NULL` = nullable) |
| `DEFAULT 'unknown'` | ✅ kept | ❌ **lost** | ✅ kept (separate default *constraint* object) |
| `INSERT ... (id, last_name) VALUES (1, NULL)` | rejected | **accepted** | **accepted** |

**Liquibase notes**
- **`renameColumn` needs `columnDataType` on MySQL.** Without it, validation fails, because Liquibase has to generate `CHANGE old new <type>`.
- **After `modifyDataType`, restate the constraints** (table `person`):
  - `addNotNullConstraint` with `columnDataType` (required on MySQL and SQL Server, which redefine the column). `defaultNullValue` fills existing NULLs first.
  - `addDefaultValue` **only on MySQL** (`dbms: mysql`). On SQL Server the default constraint survived, and adding a second one fails.
- Check the result with `./run.sh L14`: `person` ends up identical on all engines, `person_naive` doesn't.

**Also on SQL Server:** `ALTER COLUMN` fails if an index, foreign key or computed column depends on the column. Drop and re-create those around the change.

**Run**
```bash
./run.sh L14
```

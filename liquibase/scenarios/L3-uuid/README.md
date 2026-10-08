# L3 — UUID

**Conflict:** only PostgreSQL and SQL Server have a real UUID type, and even they disagree on how to sort it.

| | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| Type generated for `uuid` | `uuid` | `char(36)` | `uniqueidentifier` |
| Storage | 16 bytes | **36 characters** | 16 bytes |
| `'not-a-uuid'` | ❌ rejected | ✅ **accepted** | ❌ rejected |
| `ORDER BY id` | byte order (left to right) | text order (= left to right) | **last group first** |

Same three rows, `ORDER BY id`:
```
postgres / mysql                        mssql
00000000-0000-0000-0000-000000000002    20000000-0000-0000-0000-000000000000
10000000-0000-0000-0000-000000000001    10000000-0000-0000-0000-000000000001
20000000-0000-0000-0000-000000000000    00000000-0000-0000-0000-000000000002
```

**Liquibase solution:** the abstract `uuid` type maps to the best available type on each engine. It can't fix the semantic differences, so be aware of them:
- **MySQL `char(36)` is text.** Nothing validates it, it's 2× bigger in rows and indexes, and comparisons follow the collation. For large tables, use `binary(16)` with `UUID_TO_BIN()`/`BIN_TO_UUID()`. The column type then goes through a per-engine property (see **L2**), and inserts need raw SQL per engine.
- **SQL Server sorts `uniqueidentifier` by its last 6 bytes first.** Keyset pagination (`WHERE id > :last ORDER BY id`) and "time-ordered" UUIDs (v7) behave differently there. `NEWSEQUENTIALID()` generates values that are sequential *in SQL Server's order*.
- **Never rely on UUID ordering across engines.** Order by a timestamp or sequence column instead.

**Run**
```bash
./run.sh L3
```

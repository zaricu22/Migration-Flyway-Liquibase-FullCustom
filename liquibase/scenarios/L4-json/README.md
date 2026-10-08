# L4 — JSON

**Conflict:** a native JSON type exists on PostgreSQL and MySQL. SQL Server 2022 has none, and the abstract Liquibase type `json` generates `json` there, which fails. Reading a nested field needs three different syntaxes.

| | PostgreSQL | MySQL | SQL Server 2022 |
|---|---|---|---|
| Storage (via property) | `jsonb` | `json` | `nvarchar(max)` |
| Invalid JSON | ❌ rejected by the type | ❌ rejected by the type | ✅ accepted, **unless** `CHECK (ISJSON(payload) = 1)` |
| Stored document | normalized (key order, whitespace) | normalized | exactly as written |
| `user.name` | `payload -> 'user' ->> 'name'` | `payload ->> '$.user.name'` | `JSON_VALUE(payload, '$.user.name')` |

**Liquibase solution**
- **Property** `json_type` for the column type.
- A **`dbms: mssql` changeset** adds the `ISJSON` check constraint that the other engines don't need.
- **One `createView` per engine** (`dbms` attribute), so the application reads the same `event_user` view everywhere and never sees the dialect.

**Also note**
- Both PostgreSQL `jsonb` and MySQL `json` rewrite the document: keys get reordered and whitespace dropped. If you must return the exact original text (signatures, audit), use PostgreSQL `json` or a text column.
- Indexing a JSON field differs too: PostgreSQL uses GIN or an expression index, MySQL a functional index with `CAST`, SQL Server a computed column + index (see **L18**).

**Run**
```bash
./run.sh L4
./run.sh L4 mssql yaml sql     # see the generated SQL for SQL Server
```

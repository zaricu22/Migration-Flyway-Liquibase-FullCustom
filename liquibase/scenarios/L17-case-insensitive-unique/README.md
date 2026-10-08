# L17 — Case-insensitive unique (email)

**Conflict:** "the same email" means different things per engine, because comparison rules come from the **collation**, and the defaults differ.

| Default | PostgreSQL | MySQL 8 | SQL Server |
|---|---|---|---|
| Collation | deterministic (byte-wise) | `utf8mb4_0900_ai_ci` | `SQL_Latin1_General_CP1_CI_AS` |
| Case | sensitive | **insensitive** (`_ci`) | **insensitive** (`_CI`) |
| Accents | sensitive | **insensitive** (`_ai`) | sensitive (`_AS`) |
| Trailing spaces | significant | significant (`NO PAD`) | **ignored** |
| Index needed | `UNIQUE (lower(email))` | plain `UNIQUE (email)` | plain `UNIQUE (email)` |

**Same inserts, different outcomes** (existing: `ana@`, `jose@`, `ivan@example.com`):

| Insert | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| `ANA@Example.com` | ❌ duplicate | ❌ duplicate | ❌ duplicate |
| `josé@example.com` | ✅ | ❌ **duplicate** (accent-insensitive) | ✅ |
| `'ivan@example.com '` (trailing space) | ✅ | ✅ | ❌ **duplicate** |
| `WHERE email = 'ANA@EXAMPLE.COM'` | **0 rows** | 1 row | 1 row |

**Liquibase solution**
- PostgreSQL: an expression index via `createIndex` with `computed: true` (`lower(email)`), in a `dbms: postgresql` changeset.
- MySQL/SQL Server: a plain unique index (`dbms: mysql, mssql`).
- **Queries differ too.** On PostgreSQL the application must search with `lower(email) = lower(?)` to match *and* to use the index.

**Alternatives on PostgreSQL:** the `citext` extension type, or a non-deterministic ICU collation (`CREATE COLLATION ci (provider = icu, locale = 'und-u-ks-level2', deterministic = false)`), which make plain `=` case-insensitive.

**Takeaway:** decide what "equal" means for your data (case? accents? spaces?) and **normalize it in the data** (lowercase, trim, see Flyway **D8**). Relying on a collation default gives different results on every engine.

**Run**
```bash
./run.sh L17
```

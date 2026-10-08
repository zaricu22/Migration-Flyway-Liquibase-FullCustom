# L16 — Partial / filtered index

**Conflict:** "unique email among **active** accounts" (soft-deleted rows may reuse the email) needs a unique index over *some* rows only. Two engines support that, and they happen to share the syntax. MySQL doesn't support it at all.

| | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| Feature | partial index | ❌ none | filtered index |
| Statement | `CREATE UNIQUE INDEX ... ON account (email) WHERE deleted_at IS NULL` | workaround below | same as PostgreSQL |
| Liquibase `createIndex` with `WHERE` | ❌ not in the open-source edition, so raw `sql` | | |

**MySQL workaround:** a generated column that contains the email only for active rows, plus a regular unique index. Unique indexes allow any number of NULLs.
```sql
ALTER TABLE account ADD COLUMN active_email varchar(100)
  GENERATED ALWAYS AS (CASE WHEN deleted_at IS NULL THEN email END) VIRTUAL;
CREATE UNIQUE INDEX ux_account_email_active ON account (active_email);
```
Side effect: `INSERT INTO account VALUES (...)` without a column list now fails, because the generated column can't receive a value.

**Result (all engines):** two deleted `ana@example.com` rows plus one active row are accepted, and a second active row is rejected.

**SQL Server trap: session SET options**
```
Msg 1934: INSERT failed because the following SET options have incorrect settings: 'QUOTED_IDENTIFIER'.
```
Once a table has a filtered index, **every session that writes to it** must run with `QUOTED_IDENTIFIER ON` (plus `ANSI_NULLS ON` and friends). JDBC/ODBC drivers set these, which is why Liquibase and apps work. `sqlcmd` doesn't (unless `-I`), and neither do some old tools and linked servers. The inspect script shows the failure first, then `SET QUOTED_IDENTIFIER ON`.

**Run**
```bash
./run.sh L16
```

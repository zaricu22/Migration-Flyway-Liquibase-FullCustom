# L11 — Reserved words as names

**Conflict:** the set of reserved words differs per engine, and so do the quote characters.

| Name | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| `user` | reserved | **not reserved** | reserved |
| `order`, `group` | reserved | reserved | reserved |
| `key` | not reserved | reserved | reserved |
| Quote characters | `"x"` | `` `x` `` (`"x"` only with `ANSI_QUOTES`) | `[x]` or `"x"` |

**Liquibase does it right in change types.** The default `objectQuotingStrategy` (`LEGACY`) knows each engine's reserved words and quotes only those:
```sql
-- postgresql
CREATE TABLE public."user" (id INTEGER NOT NULL, name VARCHAR(50), "group" VARCHAR(20), ...);
-- mysql (user is not reserved there -> not quoted)
CREATE TABLE l11.user (id INT NOT NULL, name VARCHAR(50) NULL, `group` VARCHAR(20) NULL, ...);
-- mssql
CREATE TABLE [user] (id int NOT NULL, name varchar(50), [group] varchar(20), ...);
```

**…but not everywhere**
- **The `references: user(id)` shorthand is raw text.** It ends up unquoted as `REFERENCES dbo.user(id)`, which fails on SQL Server with *Incorrect syntax near the keyword 'user'*. PostgreSQL happens to accept `public.user`. Use `referencedTableName` + `referencedColumnNames`, which Liquibase quotes: `REFERENCES [user](id)`.
- **Raw `sql` is never quoted for you.** PostgreSQL and SQL Server both accept `"x"`, but MySQL needs backticks, hence two `dbms` variants of the view.

**The nastiest trap: no error at all**
```sql
SELECT * FROM user;      -- PostgreSQL: returns ONE row, column "user" = 'demo'
```
In PostgreSQL an unquoted `user` is the `CURRENT_USER` function, so the query "works" and returns the connected role name instead of your table. MySQL returns the table (not reserved there), and SQL Server raises a syntax error.

**Recommendation:** avoid reserved words as names (`app_user`, `customer_order`, `user_group`). If you inherit them, keep them in change types (quoted automatically) and quote them explicitly in every raw SQL statement and in the application.

**Run**
```bash
./run.sh L11
```

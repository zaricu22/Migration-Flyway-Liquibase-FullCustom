# L2 — Large text & Unicode

**Conflict:** "a string column" means different things per engine: how long it can be, and whether it can store Unicode at all.

| Abstract type | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| `varchar(n)` | `varchar(n)` (UTF-8) | `varchar(n)` (DB charset, `utf8mb4` = full Unicode) | `varchar(n)`: **code page only**, no Unicode |
| `nvarchar(n)` | `varchar(n)` | `varchar(n)` | `nvarchar(n)` (UTF-16) |
| `text` | `text` (1 GB) | `TEXT` (**64 KB**) | `varchar(max)`: **no Unicode** |
| `clob` | `text` | `LONGTEXT` (4 GB) | `varchar(max)`: **no Unicode** |
| `nclob` | `text` | `LONGTEXT` | `nvarchar(max)` |

**What happens** (`body_naive` uses the abstract `text` type):
```
mssql  body       = 'Smile 😀 and rocket 🚀'
mssql  body_naive = 'Smile ?? and rocket ??'     <- silent data loss, no error
       'Ђорђе'   -> '?????',   '日本語' -> '???',   'čćđ' -> 'ccd'
```
SQL Server stores `varchar` in the collation's code page (`SQL_Latin1_General_CP1_CI_AS`). Everything outside it becomes `?` or a "best fit" letter, **without an error**.

**Liquibase solution:** per-engine **properties**
```yaml
- property: { name: unicode_string, value: varchar,       dbms: "postgresql, mysql" }
- property: { name: unicode_string, value: nvarchar,      dbms: mssql }
- property: { name: unicode_text,   value: text,          dbms: postgresql }
- property: { name: unicode_text,   value: longtext,      dbms: mysql }
- property: { name: unicode_text,   value: nvarchar(max), dbms: mssql }
...
type: ${unicode_string}(200)
```

**More traps**
- **MySQL `TEXT` holds 65,535 *bytes*.** With `utf8mb4`, that can be as few as ~16,000 characters. Use `longtext` (or `mediumtext`).
- **MySQL `nvarchar` / `nclob`**: Liquibase emits `NVARCHAR` / `LONGTEXT CHARACTER SET utf8`, and `utf8` means the old 3-byte `utf8mb3`, **without emoji**. Rely on a `utf8mb4` database default and use plain `varchar` instead.
- **Literals:** a raw-SQL `INSERT ... VALUES ('Ђорђе')` on SQL Server also loses the characters, even into `nvarchar`, unless written as `N'Ђорђе'`. `loadData` (used here) sends values as JDBC parameters, which is Unicode-safe everywhere.
- **Check the client too.** The mysql CLI with a latin1 connection *shows* `?` even though the data is fine. `run.sh` uses `--default-character-set=utf8mb4`.

**Run**
```bash
./run.sh L2
```

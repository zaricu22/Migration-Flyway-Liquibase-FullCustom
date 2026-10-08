# L12 — Case sensitivity of names

**Conflict:** the same `CustomerOrder` name ends up case-sensitive on one engine and case-insensitive on another. On PostgreSQL, Liquibase's own quoting decides which.

| | PostgreSQL | MySQL (Linux) | SQL Server |
|---|---|---|---|
| Unquoted names | folded to **lower case** | kept as written | kept as written |
| Table names | exact match if quoted | **case-sensitive** (`lower_case_table_names=0`) | case-insensitive (`*_CI_*` collation) |
| Column names | exact match if quoted | case-insensitive | case-insensitive |
| Same DB on Windows/macOS | — | table names case-**in**sensitive | — |

**What Liquibase creates for `tableName: CustomerOrder`**

| Strategy | PostgreSQL | Consequence |
|---|---|---|
| `LEGACY` (default) | `CREATE TABLE public."CustomerOrder" ("Id" ..., "OrderDate" ...)` | **quoted mixed case**: `SELECT * FROM CustomerOrder` → *relation "customerorder" does not exist*. Every query has to write `"CustomerOrder"` |
| `QUOTE_ONLY_RESERVED_WORDS` | `CREATE TABLE public.customerinvoice (id ..., invoicedate ...)` | folded: any unquoted spelling works |
| `QUOTE_ALL_OBJECTS` | everything quoted | like LEGACY, but also for lowercase names |

Results:
```
postgres   SELECT * FROM CustomerOrder;      ERROR: relation "customerorder" does not exist
           SELECT * FROM "CustomerOrder";    OK
           SELECT * FROM CUSTOMERINVOICE;    OK  (folded to customerinvoice)
mysql      SELECT * FROM CustomerOrder;      OK
           SELECT * FROM customerorder;      ERROR 1146: Table 'l12.customerorder' doesn't exist
           SELECT orderdate FROM ...;        OK  (columns are case-insensitive)
mssql      any spelling                      OK
```

**Recommendations**
- **Use `lower_snake_case` for every name.** It behaves the same on all engines, quoted or not.
- If you inherit CamelCase names and target PostgreSQL, set `objectQuotingStrategy: QUOTE_ONLY_RESERVED_WORDS` (per changeset, or for the whole changelog in the root element). Otherwise Liquibase creates quoted mixed-case objects.
- Test MySQL on **Linux**. Code that works on a developer's Windows/macOS MySQL (case-insensitive table names) can break in production.

**Run**
```bash
./run.sh L12
./run.sh L12 postgres yaml sql    # see the quoting Liquibase generates
```

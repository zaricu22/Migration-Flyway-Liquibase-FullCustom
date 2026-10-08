# L21 — SQL Server: a default constraint blocks dropping the column

**Conflict:** on PostgreSQL and MySQL a column's default is a property of the column. On SQL Server it is a separate **constraint object**. Without an explicit name it gets a generated one (`DF__customer__is_vip__3B75D760`), and as long as it exists, **the column can't be dropped**. It is probably the most common SQL Server migration failure.

> **Not yet run against the containers.** The results below are the expected behavior; run the commands to confirm them.

| | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| `ADD is_vip smallint NOT NULL DEFAULT 0` | default = column property | default = column property | default = **constraint** `DF__customer__is_vi__<hex>` |
| `DROP COLUMN is_vip` | ✅ default goes with it | ✅ default goes with it | ❌ *The object 'DF__…' is dependent on column 'is_vip'. ALTER TABLE DROP COLUMN is_vip failed because one or more objects access this column.* |

The generated name is **different in every database** (dev, test, production), so a hand-written `ALTER TABLE customer DROP CONSTRAINT DF__customer__is_vi__3B75D760` works on one environment and fails on the next.

**Failure demo** (`failure-demo.yaml`: raw SQL adds the column with an unnamed default, then drops it):
```
postgres  update OK
mysql     update OK
mssql     update FAILED at 3-drop-is-vip   (1-2 recorded, the column and its DF__ constraint stay)
```

**The portable pattern** (`changelog.yaml`)
1. **`dropDefaultValue` before `dropColumn`.** On SQL Server, Liquibase generates a small dynamic SQL block that looks up the default constraint's current name in `sys.default_constraints` and drops it. On PostgreSQL and MySQL it's a plain `ALTER ... DROP DEFAULT`. Check the generated SQL with `./run.sh L21 mssql yaml sql`.
2. **Name new defaults:** `defaultValueConstraintName: df_customer_status`. SQL Server uses the name (`is_system_named = 0` in the inspect output); the other engines ignore it. Every environment then has the same name, and hand-written scripts can rely on it.
3. **Don't count on `dropColumn` alone.** Whether it removes dependent defaults on SQL Server depends on the Liquibase version and isn't documented as guaranteed; the explicit `dropDefaultValue` works everywhere.

**Other objects that block a column drop on SQL Server** (same error 5074): indexes and statistics on the column, `CHECK` and `FOREIGN KEY` constraints, computed columns, and schema-bound views or functions. They have to be dropped first, in the same changeset order.

**Run**
```bash
CHANGELOG=failure-demo ./run.sh L21          # fails only on SQL Server
./run.sh L21                                 # the portable pattern on all three engines
./run.sh L21 mssql yaml sql                  # the SQL Liquibase generates for SQL Server
```

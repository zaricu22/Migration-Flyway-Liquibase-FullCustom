# L13 — Identifier length limits

**Conflict:** the maximum name length differs, and PostgreSQL doesn't fail on longer names: it **truncates them silently**.

| | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| Max identifier length | **63 bytes** | 64 characters | 128 characters |
| Longer name | `NOTICE: identifier ... will be truncated` → stored with 63 chars | ❌ `Identifier name ... is too long` | ❌ error |

**What this scenario shows** (64-character index name `ix_shipment_tracking_event_carrier_code_status_created_on_region`):

| Changeset | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| 2 `createIndex` (64 chars) | created as **63 chars** | created (exactly at the limit) | created |
| 3 `indexExists` precondition → `dropIndex` | precondition compares 64 ≠ 63 → **`MARK_RAN`**, index **not dropped** | `EXECUTED`, dropped | `EXECUTED`, dropped |

```
postgres  3-drop-long-index-if-exists | MARK_RAN     <- silently skipped, the index is still there
mysql     3-drop-long-index-if-exists | EXECUTED
```

**More consequences of truncation**
- Two names that differ only after character 63 become the **same** name. The second `CREATE INDEX ..._regio2` fails with *relation "..._regio" already exists*.
- Schema-diff tools (Liquibase `diff`, ORMs validating the schema) see a different name than the one in your code.

**Recommendations**
- Keep constraint and index names short and explicit (≤ 30 characters is a safe, portable habit; Oracle before 12.2 allowed only 30).
- Name constraints yourself (`foreignKeyName`, `indexName`, `primaryKeyName`) instead of relying on generated names like `fk_<table>_<column>_<table>_<column>`.

**Run**
```bash
./run.sh L13
```

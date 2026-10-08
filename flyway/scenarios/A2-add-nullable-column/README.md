# A2 — Add a nullable column

**Goal:** the cheapest schema change there is, and proof that it doesn't touch existing rows.

| Version | What it does |
|---|---|
| V1 | `customer` with 200,000 rows. Records the table's physical file (`pg_relation_filenode`) |
| V2 | `ADD COLUMN phone varchar(32)` (nullable, no default). Records the filenode again |

**Key points**
- Only the catalog changes. Existing rows read the new column as `NULL`, so it is instant regardless of table size.
- The filenode stays the same, which proves the table was **not rewritten**.
- The statement still needs a brief `ACCESS EXCLUSIVE` lock. On a busy table, protect it with `lock_timeout` (see **A8**).

**Run**
```bash
./run.sh A2 all
```

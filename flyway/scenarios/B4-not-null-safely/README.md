# B4 â€” Make a column NOT NULL safely

**Goal:** `SET NOT NULL` on a large, live table without a long full-table scan under `ACCESS EXCLUSIVE`.

| Version | What it does | Lock / cost |
|---|---|---|
| V1 | `customer.country_code` nullable, 300,000 rows, ~10% NULL | — |
| V2 | `SET DEFAULT 'US'` + `ADD CONSTRAINT ... CHECK (country_code IS NOT NULL) NOT VALID` | Brief, no scan |
| V3 | Backfill existing NULLs | Row locks only |
| V4 | `VALIDATE CONSTRAINT` | Scan under `SHARE UPDATE EXCLUSIVE`, traffic continues |
| V5 | `SET NOT NULL` (skips the scan thanks to the validated CHECK), then drop the CHECK | Brief |

**Key points**
- A direct `ALTER COLUMN ... SET NOT NULL` scans the whole table while blocking reads and writes.
- PG12+ skips that scan if a **validated** `CHECK (col IS NOT NULL)` exists. V5 enables `client_min_messages = debug1`, so Flyway's output shows PostgreSQL confirming it ("existing constraints on column ... are sufficient to prove that it does not contain nulls").
- **Constraint first, backfill second.** If you backfill first, any NULL an app writes between the backfill and the constraint makes `VALIDATE` fail. The `NOT VALID` constraint closes that window, because it rejects new NULLs immediately.
- The default in V2 matters: from V2 on, new NULL writes are **rejected**, so apps that omit the column need to get a value.
- PostgreSQL 18 can do this in one step: `ALTER TABLE ... ADD CONSTRAINT ... NOT NULL country_code NOT VALID` + `VALIDATE`.

**Run**
```bash
./run.sh B4 clean
./run.sh B4 migrate 1 && ./run.sh B4 sql app_insert_null.sql   # NULL accepted
./run.sh B4 migrate 2 && ./run.sh B4 sql app_insert_null.sql   # NULL rejected (check violation)
./run.sh B4 migrate   && ./run.sh B4 verify                     # watch the debug line in V5
```

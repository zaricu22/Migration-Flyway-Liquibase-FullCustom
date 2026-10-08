# A3 — Add a column with a default

**Goal:** show that `ADD COLUMN ... DEFAULT` is either instant or a full table rewrite, depending on **what kind** of default it is.

| Version | What it does | Rewrite? |
|---|---|---|
| V1 | `customer` with 200,000 rows | — |
| V2 | `ADD COLUMN status ... NOT NULL DEFAULT 'active'` (constant) | **No.** The value lives in `pg_attribute.attmissingval` (PG11+) |
| V3 | `ADD COLUMN external_ref uuid NOT NULL DEFAULT gen_random_uuid()` (volatile) | **Yes.** Every row needs its own value |

**Key points**
- Constant defaults (literals, and also `now()`, which is *stable*, not volatile) are instant.
- Volatile defaults (`gen_random_uuid()`, `random()`, `clock_timestamp()`, sequences) rewrite the table under `ACCESS EXCLUSIVE`, which is an outage on large tables.
- Zero-downtime alternative for V3: add the nullable column, `SET DEFAULT` (affects only new rows), then backfill in batches. See **D13** and **D2**.

**Run**
```bash
./run.sh A3 all
```

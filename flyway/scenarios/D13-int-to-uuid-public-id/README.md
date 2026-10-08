# D13 — Int → UUID public identifier

**Goal:** stop exposing sequential ids in the API (`/customers/42` is guessable and leaks how many customers you have). Add a random `public_id uuid` **next to** the internal `bigint` id, on a 300,000-row table, without a rewrite or a long lock.

| Version | What it does | Cost |
|---|---|---|
| V1 | `customer(id bigint)` | — |
| V2 | `ADD COLUMN public_id uuid` + **separate** `SET DEFAULT gen_random_uuid()` | Instant |
| V3 | Batched backfill, commit per batch | Row locks only |
| V4 | `CREATE UNIQUE INDEX CONCURRENTLY` | No write blocking |
| V5–V6 | `CHECK (public_id IS NOT NULL) NOT VALID` → `VALIDATE` | Brief / online scan |
| V7 | `SET NOT NULL` (no scan), `UNIQUE USING INDEX` | Metadata only |

This scenario combines several earlier patterns: **A3** (volatile default), **D2** (batching), **A4/A5** (concurrent unique index), **B4** (safe NOT NULL). `_demo_filenode` proves the table was never rewritten.

**Key points**
- **`ADD COLUMN ... DEFAULT gen_random_uuid()` in one statement rewrites the table**, because the default is volatile. Adding the column first and setting the default in a second statement is instant. The default then applies only to new rows.
- **Why keep the bigint id?** It's smaller and sequential, so it's better for PKs, FKs and joins. The UUID is only the external identifier.
- **Random UUIDs (v4) scatter index inserts** across the whole B-tree. For large, insert-heavy tables, time-ordered UUIDv7 is friendlier (`uuidv7()` is built in from PostgreSQL 18).

**Run**
```bash
./run.sh D13 all
./run.sh D13 sql app.sql
```

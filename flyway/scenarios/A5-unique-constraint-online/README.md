# A5 — Add a unique constraint online

**Goal:** add a `UNIQUE` constraint to a large, live table without blocking writes during the index build.

| Version | What it does |
|---|---|
| V1 | `customer` with 200,000 rows |
| V2 | `CREATE UNIQUE INDEX CONCURRENTLY` (non-transactional) |
| V3 | `ADD CONSTRAINT ... UNIQUE USING INDEX` (instant, metadata only) |

**Key points**
- `ADD CONSTRAINT ... UNIQUE (email)` builds the index while blocking all writes. Splitting it into a concurrent build plus `USING INDEX` avoids that.
- The same pattern works for `PRIMARY KEY USING INDEX` (used in **B7** and **B9**).
- If the data contains duplicates, V2 fails and leaves an `INVALID` index (see **A4**). Deduplicate first (**D4**).

**Run**
```bash
./run.sh A5 all
```

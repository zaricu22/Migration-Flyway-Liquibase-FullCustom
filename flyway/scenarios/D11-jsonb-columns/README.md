# D11 — JSONB ↔ columns

**Goal:** move data in both directions between JSONB and real columns.
- Keys that are queried all the time become **typed columns**.
- Sparse, rarely used columns get **packed into JSONB**.

| Version | Direction | What it does |
|---|---|---|
| V1 | — | `preferences jsonb` with inconsistent shapes; sparse `fax`/`twitter`/`skype` columns |
| V2 | JSON → columns | `newsletter boolean`, `language varchar(5)`, converted per JSON type. Adds a CHECK and a partial index |
| V3 | JSON → columns | Remove the extracted keys from the JSON (single source of truth) |
| V4 | Columns → JSON | `contact_extra = jsonb_strip_nulls(jsonb_build_object(...))`, GIN index, drop the columns |

**Key points**
- **JSON has no schema, so expect every shape.** `"newsletter"` shows up as `true`, `"yes"`, `1`, missing, or `null`. `jsonb_typeof()` handles each one explicitly. A blind `::boolean` cast fails on numbers and objects.
- **Legacy key names:** old documents use `"lang"`, newer ones `"language"`. `coalesce()` reads both.
- **Contract step (V3):** once the app reads the columns, remove the keys from the JSON. Otherwise two sources of truth drift apart. Keys nobody extracted (`theme`) stay in the JSON.
- **Packing:** `jsonb_strip_nulls` avoids `{"fax": null, ...}` noise, and `nullif(..., '{}')` keeps rows without data at `NULL`.
- **When to use which:** use columns for data you filter, join, constrain or report on. Use JSONB for optional, sparse or schemaless data. A `jsonb_path_ops` GIN index supports `@>` containment queries.

**Run**
```bash
./run.sh D11 all
```

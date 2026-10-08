# B5 — Split a column (`full_name` → `first_name`, `last_name`)

**Goal:** a 1 → N column transformation while the old app keeps writing `full_name`.

| Version | Phase | What it does |
|---|---|---|
| V1 | — | `customer(full_name)` including edge cases: `Mary Ann Evans`, `Cher`, `'  Alan   Turing  '` |
| V2 | Expand | Add `first_name`, `last_name`, helper functions `name_first()`/`name_last()`, and a bidirectional sync trigger |
| V3 | Migrate | Backfill with the same functions, `first_name SET NOT NULL` |
| — | Deploy | App v2 writes `first_name`/`last_name` |
| V4 | Contract | Drop trigger, functions and `full_name` |

**Key points**
- **The splitting rule is a business decision.** Here the last word is the last name, and a single word is only a first name. Write the rule down and test the edge cases (multi-word names, single names, extra whitespace).
- The trigger and the backfill use the **same functions**, so old and new rows follow identical rules.
- The trigger splits when app v1 writes `full_name`, and joins with `concat_ws` when app v2 writes the parts.
- Splitting is lossy in reverse. `concat_ws(' ', first, last)` normalizes whitespace, so re-joined values can differ from the originals.

**Run step by step**
```bash
./run.sh B5 clean
./run.sh B5 migrate 2 && ./run.sh B5 sql app_v1.sql     # new row is split by the trigger
./run.sh B5 migrate 3 && ./run.sh B5 sql app_v2.sql     # full_name is joined by the trigger
./run.sh B5 migrate   && ./run.sh B5 verify
```

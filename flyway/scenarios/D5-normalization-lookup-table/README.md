# D5 — Normalization: free text → lookup table + FK

**Goal:** replace the free-text `product.category` (`Books`, `' books'`, `BOOKS`...) with a `category` table and a FK.

| Version | Phase | What it does |
|---|---|---|
| V1 | — | 30,000 products, 3 real categories in 8 spellings, some NULL |
| V2 | Expand | `category` table with a unique index on `lower(trim(name))`. Filled with one row per normalized value, named after the **most common spelling** (`mode()`). Adds `product.category_id` FK + index, and a trigger that resolves free text written by app v1 |
| V3 | Migrate | Backfill `category_id` by joining on the same normalized key |
| — | Deploy | App v2 writes `category_id` |
| V4 | Contract | Drop trigger and the text column |

**Key points**
- **One normalization key everywhere** (`lower(trim(...))`): in the unique index, the grouping, the backfill join and the trigger. If two places use different rules, rows end up unmatched.
- **Choosing the display name:** the most frequent original spelling is a good default. Otherwise, curate the list by hand in the migration.
- The trigger keeps app v1 working, including **new** categories it invents (`INSERT ... ON CONFLICT DO NOTHING`, then look up the id).
- Rows without a category stay `NULL`. The verify step checks that exactly those rows are unmatched, so nothing fell through the cracks.

**Run step by step**
```bash
./run.sh D5 clean
./run.sh D5 migrate 2 && ./run.sh D5 sql app_v1.sql   # '  BoOkS' -> Books, 'Garden Tools' created
./run.sh D5 migrate 3 && ./run.sh D5 sql app_v2.sql
./run.sh D5 migrate   && ./run.sh D5 verify
```

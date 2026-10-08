# A1 — Add a table + FK to an existing table

**Goal:** the baseline additive change: a new table that references an existing one.

| Version | What it does |
|---|---|
| V1 | `customer` with 1,000 rows |
| V2 | New `customer_note` table with a FK to `customer`, plus an index on the FK column |

**Key points**
- Creating a new table is safe. The FK validation is instant because the new table is empty.
- The FK takes a `SHARE ROW EXCLUSIVE` lock on the **referenced** table (`customer`) for a moment: writes to `customer` wait, reads don't.
- PostgreSQL does **not** index FK columns automatically, so add the index yourself. Without it, `ON DELETE CASCADE` and joins do sequential scans on the child table.

**Run**
```bash
./run.sh A1 all
```

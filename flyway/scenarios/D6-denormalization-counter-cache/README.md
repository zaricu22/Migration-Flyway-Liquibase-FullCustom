# D6 — Denormalization / counter cache

**Goal:** store `orders_count` and `last_order_at` on `customer` instead of computing them on every read. Backfill them and keep them correct.

| Version | What it does |
|---|---|
| V1 | 5,000 customers, 200,000 orders |
| V2 | Add `orders_count` (default 0) and `last_order_at` + an `AFTER INSERT/DELETE/UPDATE OF customer_id` trigger on `orders` |
| V3 | Backfill with **absolute** values from `GROUP BY` |

**Key points**
- **Trigger first, backfill second.** Changes made after the trigger exists are tracked, and the backfill then sets the absolute truth.
- **The race:** the backfill reads a snapshot. An order inserted while it runs can be counted twice or lost, leaving the counter off by one. With live traffic, run the **reconciliation** (`demo_reconcile.sql`) after the backfill, and keep it as a periodic job. Denormalized data drifts eventually (bulk loads with triggers disabled, manual fixes...).
- **Counters are incremental, MAX isn't.** Deleting the latest order means recomputing `last_order_at` from the remaining rows.
- **Hot rows:** every order insert updates the same customer row, so a customer with many parallel orders becomes a lock hotspot. For very hot counters, consider periodic aggregation instead of a trigger.

**Run**
```bash
./run.sh D6 all
./run.sh D6 sql app.sql            # insert / move / delete orders, counters follow
./run.sh D6 sql demo_reconcile.sql # simulates a trigger-bypassing import (50 drifted), then fixes it
./run.sh D6 verify
```

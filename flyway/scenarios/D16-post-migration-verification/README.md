# D16 — Post-migration verification

**Goal:** split a denormalized `legacy_order_line` table into `orders` + `order_line`, and **prove** the result is complete and correct *inside the migration*. If anything is off, the migration fails and rolls back.

| Version | What it does |
|---|---|
| V1 | 20,000 orders as ~60,000 denormalized lines, including legit identical lines (same SKU twice on one order) |
| V2 | Target tables, `verify_order_migration()` function, header-consistency **pre-check**, transform, **verification in the same transaction** |
| V3 | Rename the source to `_backup_legacy_order_line` instead of dropping it |

**The verification checks independent invariants**

| # | Check | Catches |
|---|---|---|
| 1 | `count(DISTINCT order_no)` = `count(orders)` | Lost or duplicated orders |
| 2 | Line count source = target | Lost or duplicated lines |
| 3 | Grand total `sum(qty * unit_price)` | Changed amounts |
| 4 | Per-order totals, `EXCEPT` in **both** directions | Errors that cancel out in the grand total |
| 5 | **Fingerprint**: `md5` of every value, sorted, on both sides | Swapped or altered values that keep counts and totals intact |
| 6 | No order without lines | Structural breakage |

**Key points**
- **Verify in the same transaction as the transform.** A `RAISE EXCEPTION` rolls everything back, so there's never a half-migrated state. Flyway shows the reason.
- **Verification is a function**, so it can be re-run later against the backup (`verify.sql` does that) or used in a dry run.
- **Pre-checks for assumptions.** "One header per order" is checked before the transform. When the data contradicts an assumption, stop rather than guess.
- **The `DISTINCT` trap:** `demo_broken_transform.sql` adds a "harmless" `DISTINCT` that merges legit identical lines. Checks 2–5 catch it.
- **Keep the source** (renamed) until the new structure has been in production for a while.

**Run**
```bash
./run.sh D16 clean && ./run.sh D16 migrate 2
./run.sh D16 sql demo_broken_transform.sql   # verification fails on the DISTINCT bug
./run.sh D16 migrate && ./run.sh D16 verify
```

# D3 — Cleanup before adding constraints

**Goal:** add FK, CHECK and NOT NULL constraints to tables full of dirty data. This is the most common reason constraint migrations fail in production.

| Version | What it does |
|---|---|
| V1 | No constraints. 50 orphan orders, negative and zero quantities, statuses like `PAID`, `' Shipped '`, `shiped`, `???`, 30 NULL emails |
| V2 | **All constraints first**, as `NOT VALID`: new bad data is blocked from now on |
| V3 | Cleanup: quarantine what can't be fixed, repair the rest, one rule per business decision |
| V4 | `VALIDATE` everything, turn the email CHECK into `SET NOT NULL` |

**The correct order is constrain, then clean, then validate.** If you clean first and add the constraint afterwards, the app can write new bad rows in between, and the constraint migration fails anyway (see **B4**).

**Traps shown here**
- A `NOT VALID` CHECK still checks **every new row version**, and an `UPDATE` creates a new row version. Updating only `status` on a row that also has a negative quantity fails with the quantity CHECK. Fix all columns of a row in **one** `UPDATE`, or remove unfixable rows first.
- **Don't silently delete.** Unfixable rows (orphans, quantity 0) go to `orders_rejected` with a reason. The verify step checks that `orders + orders_rejected` still equals the original count.
- **Each rule is a business decision**: `abs()` for negative quantities, `on_hold` for unknown statuses, a fake `@invalid.example` email. Write the reasons in the migration.
- **Measure before writing rules.** `demo_report.sql` counts violations per constraint and lists the distinct bad values.

**Run**
```bash
./run.sh D3 clean && ./run.sh D3 migrate 1
./run.sh D3 sql demo_report.sql     # what's broken + direct ADD CONSTRAINT failing
./run.sh D3 migrate && ./run.sh D3 verify
```

# D4 — Deduplication before a UNIQUE constraint

**Goal:** merge duplicate customers (same email, different casing and whitespace), repoint everything that references them, then enforce uniqueness.

| Version | What it does |
|---|---|
| V1 | 5,000 customers + 600 duplicates, with `orders` and `wishlist` (PK `customer_id, product_id`) pointing to both |
| V2 | One transaction: survivor map → merge attributes → repoint children → delete duplicates → normalize → unique index |

**Steps**
1. **Pick a survivor per group.** Here the oldest account wins (`first_value() OVER (PARTITION BY lower(trim(email)) ORDER BY created_at, id)`). The `customer_merge_map` table is kept as an audit trail.
2. **Merge attributes.** The survivor takes values it's missing (the phone number) from its duplicates.
3. **Repoint child rows.**
   - `orders` is a simple `UPDATE`.
   - **Trap:** `wishlist` has a unique key including `customer_id`. When the survivor and a duplicate both have product 1, a plain `UPDATE` raises a unique violation. Instead, `INSERT ... ON CONFLICT DO NOTHING` for the survivor, then delete the duplicate's rows.
4. **Delete the duplicates.** The FKs deliberately have **no `ON DELETE CASCADE`**. A forgotten child table makes the `DELETE` fail and roll everything back, instead of silently losing rows. Columns without FKs (log tables, other services) are not protected, so search for them.
5. **Normalize and add the unique index in the same transaction**, so no new duplicate can slip in between.

**Verification:** `_demo_expected` is computed in V1 *before* the merge. It records distinct customers, order count and total amount, and distinct wishlist items. `verify.sql` compares against it.

**Run**
```bash
./run.sh D4 clean && ./run.sh D4 migrate 1
./run.sh D4 sql demo_find_duplicates.sql
./run.sh D4 migrate && ./run.sh D4 verify
```

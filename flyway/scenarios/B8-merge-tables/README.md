# B8 — Merge two tables into one

**Goal:** fold the 1:1 side table `customer_profile` back into `customer` (the reverse of **B6**). This scenario uses a different technique: a view with `INSTEAD OF` triggers replaces the old table.

| Version | Phase | What it does |
|---|---|---|
| V1 | — | `customer` + `customer_profile(customer_id PK/FK, bio, avatar_url)` |
| V2 | Expand | Add `bio`, `avatar_url` to `customer` + one-way sync trigger `customer_profile → customer` |
| V3 | Migrate | Backfill from `customer_profile` |
| V4 | Switch | Drop the table, create a **view** `customer_profile` over `customer`, with `INSTEAD OF INSERT/UPDATE/DELETE` triggers |
| — | Deploy | App v2 uses `customer.bio` / `avatar_url` |
| V5 | Contract | Drop the view and function |

**Key points**
- In V2 and V3 only app v1 writes profiles, so a **one-way** trigger is enough. Compare with the bidirectional sync in **B6**.
- After V4, `customer` is the source of truth. The view keeps the old name and columns, so app v1 doesn't notice.
- This view isn't automatically updatable in the right way: an `INSERT` would mean "new customer". `INSTEAD OF` triggers turn *insert profile* into *update customer*, *delete profile* into *clear columns*, and raise the same FK error the old table would have.
- Compared with **B2**: a pure rename can use a plain auto-updatable view. A structural change needs `INSTEAD OF` logic.

**Run step by step**
```bash
./run.sh B8 clean
./run.sh B8 migrate 3 && ./run.sh B8 sql app_v1.sql                               # table + trigger
./run.sh B8 migrate 4 && ./run.sh B8 sql app_v1.sql && ./run.sh B8 sql app_v2.sql  # view + INSTEAD OF
./run.sh B8 migrate   && ./run.sh B8 verify
```

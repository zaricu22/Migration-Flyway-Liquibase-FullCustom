# B6 — Split a table (`customer.address_*` → `address`)

**Goal:** move a group of columns into a new 1:1 table without breaking the running app.

| Version | Phase | What it does |
|---|---|---|
| V1 | — | `customer(email, street, city, zip)`, 20,000 rows (some without an address) |
| V2 | Expand | `address(customer_id PK/FK, street, city, zip)` + sync triggers in **both directions** |
| V3 | Migrate | `INSERT ... SELECT` existing addresses (`ON CONFLICT DO NOTHING`) |
| — | Deploy | App v2 reads and writes `address` |
| V4 | Contract | Drop triggers, functions and the columns on `customer` |

**Key points**
- **Two tables syncing each other can loop forever.** Two guards prevent it:
  - `pg_trigger_depth() > 1` stops a trigger fired by the other trigger.
  - `IS DISTINCT FROM` skips writes that change nothing.
- The backfill uses `ON CONFLICT DO NOTHING` because the trigger may already have created rows for customers that app v1 touched after V2.
- `customer_id` as the primary key of `address` enforces the 1:1 relationship. **B7** turns it into 1:N.

**Run step by step**
```bash
./run.sh B6 clean
./run.sh B6 migrate 2 && ./run.sh B6 sql app_v1.sql                               # trigger copies into address
./run.sh B6 migrate 3 && ./run.sh B6 sql app_v2.sql && ./run.sh B6 sql app_v1.sql  # v2 change visible to v1
./run.sh B6 migrate   && ./run.sh B6 verify
```

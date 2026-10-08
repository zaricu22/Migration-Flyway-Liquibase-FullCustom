# B7 — Change cardinality 1:1 → 1:N

**Goal:** a customer goes from *at most one* address to *many addresses, exactly one primary*.

| Version | Phase | What it does |
|---|---|---|
| V1 | — | `address.customer_id` is the PK (1:1) |
| V2 | Expand | Add `id` (identity) and `is_primary boolean NOT NULL DEFAULT true` |
| V3 | Expand | Unique index on `id`, **partial** unique index `(customer_id) WHERE is_primary`, plain index on `customer_id` |
| — | Deploy | App v2 filters `WHERE is_primary` and stops using `ON CONFLICT (customer_id)` |
| V4 | Contract | Drop the old PK and use `PRIMARY KEY USING INDEX address_id_uq` (metadata only) |

**Key points**
- **A relationship change is also an app contract change.** App v1 assumes one row per customer: `SELECT ... WHERE customer_id = ?` returns one row, and `ON CONFLICT (customer_id)` works. Both break after V4, so app v2 has to be deployed first.
- "One primary per customer" is enforced by a **partial unique index**. The rule only applies to rows `WHERE is_primary`.
- Switching the primary address takes two statements (unset, then set). A non-deferrable unique index is checked row by row, so setting the new one first would conflict.
- All indexes are built **before** the switch, so V4 is only a short metadata change.
- Adding an identity column (V2) rewrites the table. That's fine for small tables. For large ones, use a nullable column, a default for new rows, and a batched backfill (**D13**, **D2**).

**Run step by step**
```bash
./run.sh B7 clean
./run.sh B7 migrate 3 && ./run.sh B7 sql app_v1.sql     # old upsert still works
./run.sh B7 migrate   && ./run.sh B7 sql app_v2.sql     # second address + primary switch
./run.sh B7 sql app_v1.sql                               # fails: ON CONFLICT (customer_id) has no unique index
./run.sh B7 verify
```

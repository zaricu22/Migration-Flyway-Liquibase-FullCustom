# B9 — Widen a PK `int` → `bigint` (with referencing FKs)

**Goal:** the identity sequence of `customer.id` (integer) is about to pass 2,147,483,647. Widen `customer.id` **and** `orders.customer_id` to `bigint` without downtime. This is the most complex scenario in the set.

`ALTER COLUMN id TYPE bigint` would rewrite both tables and all their indexes while holding `ACCESS EXCLUSIVE` locks, for minutes to hours on real tables.

| Version | What it does | Cost |
|---|---|---|
| V1 | `customer(id int)` 20,000 rows, `orders(customer_id int FK)` 200,000 rows, sequence ~1,000 ids from the limit | — |
| V2 | Shadow columns `customer.id_new`, `orders.customer_id_new` (bigint) + sync triggers | Instant |
| V3 | Batched backfill (non-transactional, commit per batch) | Row locks only |
| V4 | `CREATE [UNIQUE] INDEX CONCURRENTLY` for the future PK and FK | No write blocking |
| V5 | `CHECK (... IS NOT NULL) NOT VALID` ×2, new FK `NOT VALID` | Brief |
| V6 | `VALIDATE CONSTRAINT` ×3 | Scans, traffic continues |
| V7 | **Swap**, one transaction, metadata only: `SET NOT NULL` (no scan), drop old columns, rename new ones, move the identity, `PRIMARY KEY USING INDEX`, `setval` | Milliseconds |

**Key points**
- Every expensive step (backfill, index builds, validation) runs **before** the swap without blocking traffic. The swap itself only changes metadata.
- **The application doesn't change.** The column names are the same afterwards, so `app.sql` works at every step.
- The identity moves to the new column. The old sequence position is saved before `DROP IDENTITY` and restored with `setval`.
- Side effects to know about:
  - The swapped columns move to the **end** of the column order, which affects `SELECT *` output.
  - Apps with cached prepared statements may see *"cached plan must not change result type"* once after the swap. Restart app instances or let them reconnect.
- Prevention: use `bigint` for every surrogate key from the start.

**Run step by step**
```bash
./run.sh B9 clean
./run.sh B9 migrate 1 && ./run.sh B9 sql app.sql            # works (ids left)
./run.sh B9 migrate 4 && ./run.sh B9 sql app.sql            # still works mid-migration
./run.sh B9 sql demo_exhaust_ids.sql                         # ERROR: nextval: reached maximum value of sequence
./run.sh B9 migrate   && ./run.sh B9 sql app.sql            # after the swap: ids beyond 2,147,483,647
./run.sh B9 sql demo_exhaust_ids.sql
./run.sh B9 verify
```

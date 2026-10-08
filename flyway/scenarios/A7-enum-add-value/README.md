# A7 — Add an enum value

**Goal:** extend a PostgreSQL enum type, and understand the transaction restriction on new values.

| Version | What it does |
|---|---|
| V1 | Enum `order_status ('new','paid','shipped')` + `orders` |
| V2 | `ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'cancelled' AFTER 'paid'` |
| V3 | `UPDATE` rows to the new value, in a separate transaction |

**Key points**
- Adding a value is a catalog-only change. No table rewrite.
- A new value **can't be used in the same transaction** that added it ("unsafe use of new value"). Keep the DDL and the data change in separate migrations. PG12+ at least allows `ADD VALUE` itself inside a transaction; older versions required a non-transactional migration.
- `AFTER`/`BEFORE` matter because enums sort by declaration order.
- Enum values **can't be removed** (renaming works: `ALTER TYPE ... RENAME VALUE`). Removing one requires a new type and a column conversion. If the list changes often, use a lookup table (**D5**) or a `CHECK` constraint instead.

**Run**
```bash
./run.sh A7 all
./run.sh A7 sql demo_same_transaction.sql
```

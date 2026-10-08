# D15 — Bulk load: drop indexes/FKs/triggers, load, recreate

**Goal:** load 400,000 rows into a table that already has a unique index, 2 secondary indexes, a FK and a row trigger, much faster than inserting them with all of that in place.

| Version | What it does |
|---|---|
| V1 | `product` (50,000 rows, PK + unique + 2 indexes + FK + `updated_at` trigger), staging table `product_import` with 400,000 rows |
| V2 | Drop the secondary/unique indexes and the FK, disable **only** the user trigger |
| V3 | **Pre-checks** (unknown categories, duplicate SKUs) → `INSERT ... SELECT` from staging |
| V4 | Recreate indexes (`maintenance_work_mem`), FK `NOT VALID` + `VALIDATE`, enable trigger, `ANALYZE`, drop staging |

**Why it's faster**
- With indexes in place, every inserted row means a random insertion into **each** index, a FK lookup and a trigger call.
- Building an index afterwards is one sorted pass over the data. `demo_timing.sql` measures the difference.

**Key points**
- **Only in a maintenance window**, or on a table the app doesn't use yet. Without the indexes, queries are slow. Without the FK and unique index, nothing stops bad data from other writers.
- **Do the constraints' job up front.** V3 checks FK targets and SKU uniqueness in the *staging* data before loading. If you skip that, bad rows are only found when V4 fails, and the data is already committed.
- **`DISABLE TRIGGER name`, not `DISABLE TRIGGER ALL`.** `ALL` also disables the internal triggers that enforce FKs.
- Whatever the disabled trigger did (`updated_at`) has to be done by the load itself.
- **`ANALYZE`** after the table grows several times over, so the planner doesn't use stale statistics.
- In real life the staging table is filled with `COPY` (the fastest way in) from a CSV. `COPY` is a psql/client operation, so it usually happens outside Flyway.

**Run**
```bash
./run.sh D15 clean && ./run.sh D15 migrate 1
./run.sh D15 sql demo_timing.sql      # with vs without indexes
./run.sh D15 migrate && ./run.sh D15 verify
```

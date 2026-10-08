# B1 — Rename a column (expand/contract)

**Goal:** rename `customer.mail` to `customer.email` while old and new app versions run side by side.

| Version | Phase | What it does |
|---|---|---|
| V1 | — | `customer(mail)` with 10,000 rows |
| V2 | Expand | Add `email`, plus a `BEFORE INSERT OR UPDATE` trigger that keeps `mail` and `email` in sync both ways |
| V3 | Migrate | Backfill `email` from `mail`, `SET NOT NULL` |
| — | Deploy | Roll out app v2 (uses `email` only), retire app v1 |
| V4 | Contract | Drop trigger, function and `mail` |

**Why not `RENAME COLUMN`?** It's instant, but every running app v1 instance fails on its next query. During a rolling deploy old and new instances run together, so for a while both names have to work.

**Key points**
- The sync trigger is bidirectional: app v1 writes `mail`, app v2 writes `email`, and both see each other's changes.
- It is a `BEFORE` trigger, so app v2 inserts (without `mail`) fill `mail` before its `NOT NULL` check runs.
- On large tables, batch the backfill (**D2**) and use the safe `NOT NULL` pattern (**B4**).

**Run step by step**
```bash
./run.sh B1 clean
./run.sh B1 migrate 1 && ./run.sh B1 sql app_v1.sql                               # only v1 works
./run.sh B1 migrate 3 && ./run.sh B1 sql app_v1.sql && ./run.sh B1 sql app_v2.sql  # both work, in sync
./run.sh B1 migrate   && ./run.sh B1 sql app_v2.sql                               # contract: only v2
./run.sh B1 sql app_v1.sql    # fails: column "mail" does not exist (expected)
./run.sh B1 verify
```

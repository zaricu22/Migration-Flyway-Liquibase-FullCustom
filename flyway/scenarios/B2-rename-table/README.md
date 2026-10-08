# B2 — Rename a table (compatibility view)

**Goal:** rename `item` to `product` while app v1 still queries `item`.

| Version | Phase | What it does |
|---|---|---|
| V1 | — | `item` table with 1,000 rows |
| V2 | Expand | `RENAME TO product` + `CREATE VIEW item AS SELECT ... FROM product`, in **one transaction**. Also renames the PK index and sequence |
| — | Deploy | Roll out app v2 (uses `product`) |
| V3 | Contract | `DROP VIEW item` |

**Key points**
- Unlike a column rename, a table rename doesn't need triggers. A simple single-table view is **automatically updatable** in PostgreSQL, so app v1 keeps inserting, updating and deleting through it.
- Doing the rename and the view in one transaction means there's never a moment where neither name exists.
- Indexes, constraints, FKs, grants and identity sequences follow the table, but keep their old *names*. Renaming them is optional but keeps the schema consistent.
- The view's column list is fixed when it's created. Columns added to `product` later won't show up in `item`.

**Run step by step**
```bash
./run.sh B2 clean
./run.sh B2 migrate 1 && ./run.sh B2 sql app_v1.sql
./run.sh B2 migrate 2 && ./run.sh B2 sql app_v1.sql && ./run.sh B2 sql app_v2.sql   # both work
./run.sh B2 migrate   && ./run.sh B2 verify
```

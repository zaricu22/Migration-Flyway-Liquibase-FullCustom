# B10 — Drop a column or table (contract only)

**Goal:** remove obsolete schema objects in a safe order, without breaking dependents and without losing data you might still need.

| Version | What it does |
|---|---|
| V1 | `customer.legacy_code` (used by view `customer_export`) + table `customer_legacy_login` (FK to `customer`) |
| V2 | Recreate the view without the column; **soft-drop** the table by renaming it to `_deprecated_customer_legacy_login` |
| V3 | A release later: `DROP COLUMN` and `DROP TABLE`, **without `CASCADE`** |

**Safe order**
1. **Stop using it.** Deploy code that no longer reads or writes the object. ORMs that validate or map every column (Hibernate `validate`, `SELECT *` mappers) count as users too.
2. **Find the dependents.** `demo_find_dependents.sql` lists views, FKs, and usage counters from `pg_stat_user_tables`.
3. **Detach the dependents.** Recreate views without the column. `CREATE OR REPLACE VIEW` can't remove columns, so drop and create in one transaction.
4. **Soft-drop.** Rename the table. Forgotten users fail loudly, but the data is still there and the rename is instantly reversible.
5. **Drop**, a release later, without `CASCADE`. If something still depends on the object, the migration should fail and say so.

**Key points**
- `DROP COLUMN` is metadata-only. The data stays in the rows until they get rewritten (`attisdropped` in the catalog). Space is reclaimed gradually, or with `VACUUM FULL` / `pg_repack`.
- `DROP ... CASCADE` in a migration silently removes whatever depends on the object, possibly a view another team uses.

**Run**
```bash
./run.sh B10 clean && ./run.sh B10 migrate 1
./run.sh B10 sql demo_find_dependents.sql
./run.sh B10 migrate && ./run.sh B10 verify
```

# D10 — Quarantine table for failed conversions

**Goal:** convert a text-only legacy table into typed columns. Rows that can't be converted go to a quarantine table with the reason. They don't abort the migration and aren't silently dropped.

| Version | What it does |
|---|---|
| V1 | `legacy_payment(paid_on text, amount text, currency text)`: 14 hand-written edge cases + 10,000 clean rows |
| V2 | Typed `payment` table + `payment_migration_error(source_id, column_name, raw_value, error)` |
| V3 | Normalize known formats → log every problem → convert the rest → quality gate |

**Techniques**
- **`pg_input_is_valid()` / `pg_input_error_info()`** (PostgreSQL 16+) test a cast *without* raising an error. Validation is set-based: no `EXCEPTION` block per row, no subtransaction per row.
- **Whitelist formats before casting.** The cast alone isn't a validator:
  - `'yesterday'`, `'today'`, `'epoch'` and `'infinity'` are **valid** PostgreSQL date inputs.
  - `'03/07/2024'` means March 7 or July 3 depending on `DateStyle`.
  - A regex decides which formats are accepted and how they're rewritten (`DD/MM/YYYY → YYYY-MM-DD`, `1.234,56 → 1234.56`).
- **One error row per problem**, with the raw value and the reason, so someone can fix the source data and re-import.
- **Quality gate:** if more than 1% of rows are rejected, the migration raises an exception and **everything rolls back**. A few bad rows are normal. Many mean the rules are wrong.
- **Completeness check** (verify): every legacy id is either in `payment` or in the quarantine, never both, never neither.

**Run**
```bash
./run.sh D10 all
```

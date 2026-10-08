# Full custom migration — a complete data migration, end to end

This folder is the **complex scenario** of the project: a runnable migration of a whole (small) legacy e-shop into a new data model.<br>
It covers every phase: assess, extract, validate, transform, reconcile, load, verify, delta sync (including deletes), cutover, rollback and cleanup.<br>
Each phase has separate scripts, gates stop the pipeline, and an audit trail records what happened.

The Flyway and Liquibase folders show individual techniques, one per scenario.<br>
This one combines the Flyway data-migration techniques (D1, D2, D3, D4, D5, D7, D8, D9, D10, D14, D15, D16) into one end-to-end process.

> **Why plain SQL and no Flyway or Liquibase?** These tools aren't powerful enough for a migration like this one, and aren't meant to be.<br>
> They **version and apply scripts**; they don't validate, transform, reconcile or quarantine data.<br>
> Complex migrations are **primarily custom SQL**: every rule in this folder (parsing, normalization, deduplication, code mapping, quarantine, reconciliation, gates, id mapping, delta sync, rollback) is hand-written SQL, and `run.sh` only decides the order and stops at a failed gate.
>
> A migration tool could replace `run.sh`, but not the SQL:
> - **Flyway's** "run each script once" model doesn't suit phases that are re-run after a fix or in rehearsals. Workable only with a separate history table and functions in `R__` scripts.
> - **Liquibase** fits better (`runAlways`, labels to run one phase, `HALT` preconditions as gates), but the logic still stays custom SQL.
>
> In industry, complex migrations are custom SQL plus an orchestrator (script, CI, Airflow), dbt for ELT transformations with tests as gates, or dedicated ETL/CDC tools (AWS/Azure DMS, Informatica, Talend, SSIS).<br>
> Flyway and Liquibase stay responsible for the **target schema**, like `00_setup/005_target_schema.sql` would be in a real project.

<!-- contents -->
**Contents**

- [Theoretical background](#theoretical-background)
  - [By what is migrated](#by-what-is-migrated)
  - [By data movement pattern](#by-data-movement-pattern)
  - [By availability during the migration](#by-availability-during-the-migration)
- [Background: migration considerations](#background-migration-considerations)
  - [Large data changes: performance and safety](#large-data-changes-performance-and-safety)
  - [Locking and transactions](#locking-and-transactions)
  - [Data types and conversion](#data-types-and-conversion)
  - [Validation and reconciliation queries: NULL traps](#validation-and-reconciliation-queries-null-traps)
  - [Performance after the migration](#performance-after-the-migration)
- [Project Layout](#project-layout)
- [Stages](#stages)
  - [Names of the data stages](#names-of-the-data-stages)
  - [Schemas: keep the stages physically separate](#schemas-keep-the-stages-physically-separate)
  - [Mig. Tables](#mig-tables)
- [Phases](#phases)
  - [Overview](#overview)
    - [The standard phases](#-the-standard-phases)
    - [What each type of script does](#-what-each-type-of-script-does)
    - [Reads and writes per phase](#-reads-and-writes-per-phase)
    - [`Gates:` How a exceptions stop the run](#-gates-how-a-exceptions-stop-the-run)
    - [`Validate, reconcile, verify`: what each one proves](#-validate-reconcile-verify-what-each-one-proves)
    - [Report (`run.sh report`)](#-report-runsh-report)
  - [Before the phases](#before-the-phases)
    - [The old system (`source/`)](#-the-old-system-source)
    - [Setup (`run.sh setup` -> all scripts from `00_setup/`)](#-setup-runsh-setup---all-scripts-from-00_setup)
  - [0 ASSESS](#0-assess)
    - [Assess (`run.sh assess` -> all scripts from `00_assess/`)](#-assess-runsh-assess---all-scripts-from-00_assess)
  - [1 EXTRACT to 6 VERIFY](#1-extract-to-6-verify)
    - [1 EXTRACT (`01_extract/`)](#-1-extract-01_extract)
    - [2 VALIDATE (`02_validate/`) → GATE 1](#-2-validate-02_validate--gate-1)
    - [3 TRANSFORM (`03_transform/`)](#-3-transform-03_transform)
    - [4 RECONCILE (`04_reconcile/`) → GATE 2](#-4-reconcile-04_reconcile--gate-2)
    - [5 LOAD (`05_load/`)](#-5-load-05_load)
    - [6 VERIFY (`06_verify/`) → GATE 3](#-6-verify-06_verify--gate-3)
  - [7 CUTOVER](#7-cutover)
    - [Delta run (`run.sh delta`)](#-delta-run-runsh-delta)
    - [Cutover (`run.sh cutover`)](#-cutover-runsh-cutover)
    - [Rollback (`run.sh rollback`)](#-rollback-runsh-rollback)
  - [8 CLEANUP](#8-cleanup)
    - [Archive and cleanup (`run.sh archive`, `run.sh cleanup`)](#-archive-and-cleanup-runsh-archive-runsh-cleanup)
- [Running the demo](#running-the-demo)
  - [Expected result of a full run](#expected-result-of-a-full-run)
  - [Walkthroughs](#walkthroughs)
  - [Relation to the Flyway scenarios](#relation-to-the-flyway-scenarios)
- [Rules that make it work](#rules-that-make-it-work)
- [Limitations](#limitations)
- [Extras beyond the phase list](#extras-beyond-the-phase-list)
<!-- /contents -->

---

## Theoretical background

Migrations are classified along several independent dimensions. This project touches three of them.

### By what is migrated

- **Storage migration**: data moves between storage systems without changing its format, for example from a SAN to cloud object storage.
- **Database migration**: data moves between database engines or engine versions, for example from Oracle to PostgreSQL or from MySQL 5.7 to 8.4. It is *homogeneous* when the engine stays the same and *heterogeneous* when it changes. Heterogeneous migrations are the hard ones, because types and SQL dialects differ. The Liquibase part of this project shows those differences.
- **Schema migration**: the structure changes inside the same database, and existing data is adapted to it: a column is renamed, a table is split, a type is changed. This is what the Flyway part of this project covers.
- **Application migration**: an application moves to a new platform together with its data, for example from a legacy ERP to a new product. **This demo is one:** an old e-shop database is migrated into the data model of a new one.
- **Cloud migration**: systems move from on-premises infrastructure to the cloud or between clouds.
- **Data center migration**: the whole infrastructure moves physically.
- **Business process migration**: data follows an organizational change, for example when the customer bases of two merged companies are combined.

### By data movement pattern

- **ETL (Extract → Transform → Load)**: data is read from the source, transformed in a separate staging area or tool, and only then loaded into the target.
- **ELT (Extract → Load → Transform)**: raw data is loaded into the target platform first and transformed there with SQL. **This demo is ELT:** the source is copied into `raw` tables and transformed into `stg` tables inside the new database.
- **Full load**: all data is copied on every run. The initial extract of this demo is a full load.
- **Incremental load**: only new or changed rows are copied, detected with a timestamp or version column. The delta sync of this demo is incremental (`updated_at` > watermark).
- **CDC (Change Data Capture)**: changes are read from the database's transaction log and streamed continuously to the target (tools like Debezium, AWS DMS or Oracle GoldenGate). CDC makes near-zero-downtime migrations between systems possible.

### By availability during the migration

- **Offline migration**: the application is stopped for the whole migration. It is the simplest approach, but the downtime grows with the amount of data.
- **Online (zero-downtime) migration**: the application keeps running while the migration happens. At the schema level this needs the expand/contract pattern: add the new structure next to the old one, keep both in sync, move the application over, then remove the old structure (Flyway scenarios B1–B10). Between systems it needs CDC or writing to both systems at once (dual-write). **This demo uses the middle ground:** an initial load while the old system keeps running, repeated delta syncs, and a short freeze with one last delta at cutover.

---

## Background: migration considerations

The examples use SQL Server (T-SQL) and PostgreSQL. The principles apply to any engine.

### Large data changes: performance and safety

- **Batch big changes.** Walk the key in ranges and commit after every batch (T-SQL: `UPDATE TOP (n)` in a loop; PostgreSQL: key ranges in a procedure). Short transactions mean short locks, controlled log growth, and progress that survives a failure. → D2, D14, `05_load/540_load_order_batched.sql`
- **Update only rows that actually change**: `WHERE ... AND Status <> @s` (T-SQL), `IS DISTINCT FROM` (PostgreSQL, NULL-safe). Fewer writes, less log, fewer locks, fewer triggers fired. → D8
- **Indexes.**
  - The index that supports a batch's `WHERE` must exist *before* the batch runs.
  - Secondary indexes that the load doesn't need can be dropped and rebuilt afterwards.
  - Unused indexes are pure cost, because every write maintains every index. → D15
- **Triggers.** Disable them only in a controlled maintenance window. Disabling skips integrity and audit logic, so the migration has to do that work itself. → D15
- **Statistics.** After a bulk change, update them (`UPDATE STATISTICS` / `ANALYZE`); stale statistics lead to bad plans even with the right indexes. → D15, `05_load/590_post_load.sql`
- **Fast copies create no structure.** `SELECT ... INTO` (T-SQL) and `CREATE TABLE ... AS` (PostgreSQL) are fast, but add no keys, constraints or indexes; add them explicitly. → D12
- **`ON DELETE CASCADE` on big tables** holds long locks that chain across tables. Delete children explicitly, in batches. → D12
- **Partitioning** turns regular archiving and purging into cheap partition operations. → D12
- **Capturing generated keys during a load.** Never use `@@IDENTITY`: it returns the last identity of the session, which can come from a trigger that inserted into another table. `SCOPE_IDENTITY()` returns a single value, which doesn't work for set-based loads. Fill the id map in the same statement with `OUTPUT inserted.id, ...` (T-SQL) / `RETURNING` (PostgreSQL), or join back on the legacy key, as this framework does (`legacy_cust_no`, `mig.id_map`).

### Locking and transactions

- **Keep transactions short** and give DDL a lock timeout (`SET LOCK_TIMEOUT` in T-SQL, `SET LOCAL lock_timeout` in PostgreSQL), so a waiting migration can't block all traffic behind it. → A8
- **Access tables in the same order** in every script and procedure. That means fewer deadlocks.
- **Reads while a migration runs.**
  - SQL Server: `READ_COMMITTED_SNAPSHOT` is safer than `NOLOCK`, which allows dirty reads and skipped or duplicated rows.
  - PostgreSQL: MVCC already keeps readers and writers from blocking each other, but DDL still takes locks.
- **Consistent extract.** Never read a live source with `NOLOCK` / `READ UNCOMMITTED` during an extract: rows can be skipped or read twice. Reconciliation then fails, or worse, doesn't notice. Read all source tables from one snapshot: SQL Server `SNAPSHOT` isolation, or one PostgreSQL transaction. This framework's extract runs in one transaction, and `postgres_fdw` reads the source in one remote transaction.
- **Dry run in a transaction.** Run a migration inside `BEGIN TRAN` … check the result … `ROLLBACK` (PostgreSQL: `BEGIN` … `ROLLBACK`).
  - It works because DDL is transactional in SQL Server and PostgreSQL. In MySQL it isn't (→ L19), and statements that can't run in a transaction (e.g. `CREATE INDEX CONCURRENTLY`) can't be tested this way either.
  - Every lock is held until the rollback, so do it on a copy, never on production.
- **Error handling in T-SQL scripts.** `SET XACT_ABORT ON` makes any error roll back the whole transaction. Only commit or roll back a transaction the script opened itself (check `@@TRANCOUNT`). In PostgreSQL, run each script in one transaction (`psql -1`, as this framework does).
- **T-SQL batches (`GO`).**
  - `CREATE PROCEDURE` / `FUNCTION` / `VIEW` / `TRIGGER` must be alone in their batch.
  - A statement that uses a column added by `ALTER TABLE` in the same batch fails at compile time, so it needs a new batch. → L9

### Data types and conversion

- **Implicit conversion.** A changed column type, or a join between columns of different types, can silently turn index seeks into scans (`CONVERT_IMPLICIT` in a SQL Server plan).
  - Keep join columns, parameters and variables the same type as the column. If a cast is needed, cast the parameter side, never the column.
  - Java: the Microsoft JDBC driver sends strings as `NVARCHAR` by default. Set `sendStringParametersAsUnicode=false` when the columns are `VARCHAR`.
- **T-SQL `VARCHAR` without a length** is `VARCHAR(1)` in declarations and columns (`VARCHAR(30)` in `CAST`), which means silent truncation. Always state the length.
- **Unicode and exact numbers.** `VARCHAR` vs `NVARCHAR` → L2. Float vs decimal (money) → B3, D9.
- **Safe conversion for quarantine.** Test whether a value converts *without* raising an error, so bad rows can be quarantined instead of aborting the migration:
  - T-SQL: `TRY_CONVERT` / `TRY_CAST` return NULL on failure.
  - PostgreSQL 16+: `pg_input_is_valid()` (→ D10, `02_validate`).
  - Handling errors row by row (`TRY/CATCH` or an `EXCEPTION` block per row) is much slower.
- **Dates depend on session settings.** T-SQL `ISDATE` / `CONVERT` follow `SET LANGUAGE` / `DATEFORMAT`, and PostgreSQL follows `DateStyle`, so `'03/07/2024'` means March or July depending on the session. Whitelist the formats explicitly (`mig.parse_date`), or convert with an unambiguous style (`CONVERT(date, x, 23)` = `YYYY-MM-DD`).
- **Silent precision loss when converting to text** (exports, CSV files, text columns). In T-SQL, `CAST(float AS varchar)` keeps only 6 significant digits (`1.23457e+006`), and `CAST(datetime AS varchar)` drops the seconds (`Sep 26 2026  3:45PM`). Use `CONVERT` with an explicit style (`121` for datetime, `3` for a lossless float, SQL Server 2016+) or an explicit format (`to_char` in PostgreSQL).

### Validation and reconciliation queries: NULL traps

A check that silently skips NULL rows can *pass* while data is missing:
- `COUNT(col)` skips NULLs, `COUNT(*)` doesn't. Count rows with `COUNT(*)`.
- `SUM` / `AVG` ignore NULLs, and `SUM` over zero rows is NULL, not 0. Use `COALESCE(SUM(x), 0)`, or compare NULL-safely.
- `col = NULL` and `col <> 'x'` never match rows where `col` is NULL. Use `IS NULL`, `IS [NOT] DISTINCT FROM` (PostgreSQL, SQL Server 2022+), or an explicit `OR col IS NULL`.
- `NOT IN (subquery)` returns **no rows at all** if the subquery returns a NULL. Use `NOT EXISTS`.

This demo's checks use `COUNT(*)`, `NOT EXISTS`, and `IS NOT DISTINCT FROM` inside `mig.check()`.

### Performance after the migration

Verification (D16, `06_verify`) proves the data is *correct*. Performance needs its own check:
- **Update statistics first**, then compare the plans of important queries before and after:
  - SQL Server: Query Store shows plan regressions and can force the last good plan.
  - PostgreSQL: `pg_stat_statements` plus `EXPLAIN (ANALYZE, BUFFERS)`.
- **Red flags:**
  - a scan where a seek was expected;
  - a large gap between estimated and actual rows (stale statistics, parameter sniffing);
  - implicit-conversion warnings;
  - sort or hash spills;
  - key lookups over many rows.
- **Changed procedures get new plans.** Test them with realistic parameter values and production-like volumes.

---

## Project Layout

```
full-custom-migration/
├── docker-compose.yml               one PostgreSQL: databases legacy_shop (old) + shop (new)
├── run.sh | run.ps1                 orchestrator: phases in order, stop at a failed gate, log to mig.run
├── archive/<timestamp>/             created by ./run.sh archive / cleanup: report.txt + mig_*.csv
├── source/
│   ├── legacy_shop.sql              the old system with its intentionally dirty data
│   └── legacy_changes.sql           new user changes in the old system after the initial load (for ./run.sh delta)
├── 00_assess/                       read-only profiling of the old system (./run.sh assess)
│   ├── 010_volumes.sql              row counts, change timestamps, lines per order, missing values per column
│   ├── 020_formats.sql              value shapes per column (99.99.9999), e-mail quality, address/name structure
│   ├── 030_keys_and_relations.sql   duplicates by normalized e-mail, orphans, inconsistent order headers
│   └── 040_value_lists.sql          every country / status / category value: input for the code maps
├── 00_setup/
│   ├── 001_schemas.sql              raw, stg, mig, src + postgres_fdw connection to the old system
│   ├── 002_control_tables.sql       mig.run, mig.error, mig.id_map, mig.code_map, ...
│   ├── 003_helpers.sql              run/phase/check/gate functions + parse/normalize rules
│   ├── 004_code_maps.sql            value mappings (needed by validation AND transformation)
│   └── 005_target_schema.sql        the new model (in real life owned by Flyway/Liquibase)
├── 01_extract/
│   ├── 110_raw_tables.sql           raw.* (all text) + "latest live version per key" views + deleted-key views
│   └── 120_load_raw.sql             full extract from src.* in one consistent snapshot + watermarks
├── 02_validate/                     reads raw, writes mig.error only
│   ├── 200_reset.sql                re-running replaces this run's findings
│   ├── 210_chk_structure.sql        parseable? e-mail, dates, amounts, quantities, phone/address (WARN)
│   ├── 220_chk_integrity.sql        orphans, inconsistent denormalized header
│   ├── 230_chk_business.sql         mappable codes, positive amounts/quantities
│   ├── 240_chk_dependencies.sql     orders of rejected customers/products are rejected too
│   └── 290_gate_validate.sql        GATE 1: reject rate <= 5 % per entity
├── 03_transform/                    raw -> stg, rebuilt from scratch every run
│   ├── 300_stg_tables.sql           stg.* + TRUNCATE
│   ├── 310_stg_customer.sql         normalize, dedupe (survivor + aliases), map country
│   ├── 320_stg_address.sql          free-text address -> street / zip / city
│   ├── 330_stg_product.sql          categories (most common spelling), prices -> cents
│   ├── 340_stg_order.sql            header/lines split, status mapping, orders -> survivor customer
│   └── 390_stg_analyze.sql          statistics + row counts
├── 04_reconcile/                    stg vs raw, results in mig.reconciliation
│   ├── 410_rec_counts.sql           raw = staged + merged + rejected, per entity
│   ├── 420_rec_totals.sql           amount totals (computed independently), per-order both directions
│   ├── 430_rec_fingerprint.sql      md5 over sorted values
│   └── 490_gate_reconcile.sql       GATE 2
├── 05_load/                         the ONLY phase that writes production
│   ├── 500_pre_load.sql             refuses to run unless validate/transform/reconcile passed
│   ├── 510_load_customer.sql        upsert by legacy key + id map (duplicates -> survivor's id)
│   ├── 520_load_address.sql         FK resolved through mig.id_map
│   ├── 530_load_product.sql         categories, then products
│   ├── 540_load_order_batched.sql   batches of 1000, COMMIT + checkpoint per batch
│   ├── 560_apply_deletes.sql        source deletes: lines/orders deleted, customers deactivated (migrated rows only)
│   └── 590_post_load.sql            ANALYZE + row counts
├── 06_verify/                       target vs stg + known facts
│   ├── 610_ver_counts_totals.sql    every staged row in production with identical values, totals
│   ├── 620_ver_constraints.sql      constraints validated, no orders without lines, id map complete
│   ├── 630_ver_business.sql         spot checks with known outcomes (+ delta expectations)
│   ├── 640_ver_deletes.sql          every source delete arrived in production
│   └── 690_gate_verify.sql          GATE 3: data is right
├── 07_cutover/
│   ├── 710_delta_sync.sql           incremental extract: changed rows (watermark), changed products (content), deleted keys (tombstones)
│   ├── 720_freeze_source.sql        cutover: old system read-only (default_transaction_read_only)
│   ├── 729_unfreeze_source.sql      NO-GO: old system writable again
│   ├── 760_smoke_test.sql           cutover: read + write path of the new system (write undone)
│   ├── 780_go_no_go.sql             GATE 4: go-live decision
│   └── 790_rollback.sql             remove exactly what the migration loaded (via mig.id_map)
└── 08_cleanup/
    └── 810_drop_raw_stg.sql         drop raw/stg/src, keep mig as the audit trail (run.sh archives the reports first)
```

> [!NOTE]
> Each file runs in **one transaction** (`psql -1`). A failing statement leaves nothing half-done.\
> The exception is files named `*_batched*`, which commit per batch themselves.

## Stages

> [!IMPORTANT]
> A **stage** (also called a *layer* or *zone*) is a place where the data rests between two steps of the migration, in one defined state: as it is in the old system, copied, prepared, or final.\
> Each stage is filled by one phase and read by the next, so every step can be checked and repeated on its own, without going back to the old system.\
> A **phase** is a step of work (extract, validate, transform, ...); a **stage** is where its result is kept.\
> A **gate** is a check that stops the run if it fails (`mig.gate(phase) in 00_setup/003_helpers.sql`), the next phase starts only after the previous gate passes.

### Names of the data stages

| Stage | Standard names | Data-warehouse naming | Influenced by Phases (see below) | In this demo |
|---|---|---|---|---|
| **Source** | **Source** / **legacy** data | — | read by **0 ASSESS** (profiling) and **1 EXTRACT** (and by the delta sync in **7 CUTOVER**) | database `legacy_shop`, read through schema `src` |
| **Raw** | **Raw** / **landing** data | **Bronze** layer | created by **1 EXTRACT**; checked by **2 VALIDATE**; read by **3 TRANSFORM** and **4 RECONCILE**; dropped by **8 CLEANUP** | schema `raw` |
| **Staging** | **Staging** data (cleansed, transformed, mapped) | **Silver** layer | created by **3 TRANSFORM**; checked against raw by **4 RECONCILE**; read by **5 LOAD** and **6 VERIFY**; dropped by **8 CLEANUP** | schema `stg` |
| **Target** | **Target** (the target schema or model) | **Gold** layer | written only by **5 LOAD**; checked by **6 VERIFY**; switched to in **7 CUTOVER** | schema `public` in database `shop` |
| *Control (not a data stage)* | **Control** / **audit** data: the audit trail of all phases (see [Mig. Tables](#mig-tables)) | — | written and read by **every phase from 1 EXTRACT on**; kept after **8 CLEANUP** as the audit trail | schema `mig` in database `shop` |

### Schemas: keep the stages physically separate

| Schema | Content | Lifetime |
|---|---|---|
| `src` | Foreign tables pointing at the old system (read-only window via `postgres_fdw`) | Until cleanup |
| `raw` | Exact copy of the source, all columns as `text`, plus `_batch_id`, `_loaded_at` and `_deleted` (tombstone of a row deleted in the source) | Until cleanup |
| `stg` | Typed, cleaned rows in (almost) the target shape, still keyed by the **legacy** keys | Until cleanup |
| `mig` | **Control tables**: runs, quarantine, mappings, id map, checkpoints, check results | Kept as the audit trail |
| `public` (target) | Production | — |

### Mig. Tables

Control tables in `mig` (all created in `00_setup/002_control_tables.sql`):

| Table | Purpose | Written by | Read by |
|---|---|---|---|
| `mig.run` | One row per pipeline run (`full`, `delta` or `cutover`): when, and with what result (`RUNNING`, `DONE`, `FAILED`, `ROLLED_BACK`) | `run.sh` / `run.ps1` via `mig.new_run()` / `mig.end_run()` (`003_helpers.sql`); `07_cutover/790_rollback.sql` (status `ROLLED_BACK`) | Every script through `mig.current_run()`; `06_verify/630_ver_business.sql` (delta checks); `07_cutover/720_freeze_source.sql` (requires a successful full run); `run.sh report` |
| `mig.run_phase` | One row per phase of a run: `RUNNING` / `DONE` / `FAILED` | `run.sh` / `run.ps1` via `mig.phase_start()` / `mig.phase_end()` | `05_load/500_pre_load.sql` via `mig.require_phase()` (the load refuses to start unless earlier phases are `DONE`); `07_cutover/780_go_no_go.sql`; `run.sh report` |
| `mig.error` | The **quarantine**: one row per problem with entity, source key, column, raw value, rule and severity (`REJECT` = not migrated, `WARN` = migrated without that value (instead used NULL / missing)) | `02_validate/200_reset.sql` (clears this run's findings), `210_chk_structure.sql`, `220_chk_integrity.sql`, `230_chk_business.sql`, `240_chk_dependencies.sql` | `02_validate/290_gate_validate.sql`; everything that reads `mig.v_rejected`; `run.sh report` |
| `mig.v_rejected` *(view)* | Rejected source keys of the current run (over `mig.error`) | — | `02_validate/240_chk_dependencies.sql`, `290_gate_validate.sql`; `03_transform/310_stg_customer.sql`, `330_stg_product.sql`, `340_stg_order.sql`; `04_reconcile/410_rec_counts.sql`, `420_rec_totals.sql`, `430_rec_fingerprint.sql` |
| `mig.code_map` | Value mappings (`'srbija'` → `RS`, `'PEND'` → `new`) | `00_setup/004_code_maps.sql` | `02_validate/230_chk_business.sql` (unmapped codes); `03_transform/310_stg_customer.sql` (country), `340_stg_order.sql` (status) |
| `mig.id_map` | Old key → new id for every migrated record. Loads resolve foreign keys through it, and it answers "where did legacy customer 1905 go?" | `05_load/510_load_customer.sql`, `530_load_product.sql` (categories, products), `540_load_order_batched.sql`; entries of deleted orders removed by `560_apply_deletes.sql`; cleared by `07_cutover/790_rollback.sql` | `05_load/520_load_address.sql`, `540_load_order_batched.sql` (FKs); `560_apply_deletes.sql` (only migrated rows are deleted / deactivated); `06_verify/620_ver_constraints.sql`, `630_ver_business.sql`; `07_cutover/790_rollback.sql` (what to delete) |
| `mig.watermark` | How far the incremental extract has read (`updated_at` per source table) | `01_extract/120_load_raw.sql` (set by the full extract); `07_cutover/710_delta_sync.sql` (moved forward) | `07_cutover/710_delta_sync.sql` (only rows after the watermark); `780_go_no_go.sql` (nothing changed after the final delta) |
| `mig.checkpoint` | Progress of batched steps, so a killed load resumes | `05_load/540_load_order_batched.sql` (per committed batch); cleared by `07_cutover/790_rollback.sql` | `05_load/540_load_order_batched.sql` (resume point) |
| `mig.reconciliation` | Every check with expected value, actual value and pass/fail. Checks of whole sets (counts, totals, fingerprints), not of individual records: record-level problems are in `mig.error` | via `mig.check()`: `02_validate/290_gate_validate.sql`; `04_reconcile/410_rec_counts.sql`, `420_rec_totals.sql`, `430_rec_fingerprint.sql`; `06_verify/610_ver_counts_totals.sql`, `620_ver_constraints.sql`, `630_ver_business.sql`, `640_ver_deletes.sql`; `07_cutover/760_smoke_test.sql`, `780_go_no_go.sql` | the gates via `mig.gate()`: `290_gate_validate.sql`, `490_gate_reconcile.sql`, `690_gate_verify.sql`, `780_go_no_go.sql`; `run.sh report` |

The helper functions are defined in `00_setup/003_helpers.sql`:

| Function | Returns | Does | Used by |
|---|---|---|---|
| `mig.current_run()` | `bigint` | the id of the latest run | every script |
| `mig.new_run(kind)` | `bigint` | starts a run (`full`, `delta`, `cutover`), status `RUNNING` | `run.sh` |
| `mig.end_run(status)` | — | ends the current run (`DONE` / `FAILED`) | `run.sh`, `mig.phase_end()` |
| `mig.phase_start(phase)` | — | records the phase as `RUNNING`; a retry re-opens a `FAILED` run | `run.sh` |
| `mig.phase_end(phase, status)` | — | records the phase as `DONE` / `FAILED`; `FAILED` also fails the run | `run.sh` |
| `mig.require_phase(phase)` | — | raises an exception unless the phase is `DONE` in this run | `05_load/500_pre_load.sql` |
| `mig.check(phase, name, expected, actual)` | `boolean` | records one check with expected / actual / ok in `mig.reconciliation` | all check scripts (`290`, 4xx, 6xx, 760, 780) |
| `mig.gate(phase)` | — | prints every check of the phase; raises an exception if any failed | `290`, `490`, `690`, `780` |
| `mig.parse_date()`, `mig.parse_amount_cents()`, `mig.normalize_email()`, `mig.normalize_phone()`, `mig.name_first()`, `mig.name_last()`, `mig.parse_address()` | `date`, `bigint`, `text`, `text[]` | parsing and normalization rules: dirty text → typed or normalized value; `NULL` if it can't be parsed | validation (`210`, `230`) and transformation (`310`, `320`, `330`, `340`) |

One procedure is defined elsewhere: `mig.load_orders(batch_size)` in `05_load/540_load_order_batched.sql`, the batched order load with checkpoint (dropped by cleanup).

---

## Phases

### Overview

#### >> The standard phases

```
 0 ASSESS      profile the source: volumes, formats, dirty data, orphans, duplicates
 1 EXTRACT     copy source 1:1 into  raw.*            (no changes, add batch id + load time)
 2 VALIDATE    check raw against rules  -> report(error) + quarantine(rejected)   [GATE 1]
 3 TRANSFORM   raw.* -> stg.*   cleanse, normalize, map codes, dedupe, split/merge, stg stats
 4 RECONCILE   stg vs raw: counts, totals, sums, fingerprints, orphans            [GATE 2]
 5 LOAD        stg.* -> target  (in FK order, batched, id mapping)
 6 VERIFY      target vs stg/raw, totals, constraints, business checks, deletes   [GATE 3]
 7 CUTOVER     freeze old system, sync delta, switch the app, keep a rollback path
 8 CLEANUP     drop raw/stg after a retention period, archive the reports
```

> [!TIP]
> Everything before **LOAD** can be re-run as often as needed, because it doesn't touch production.

#### >> What each type of script does

| Type | Files | Reads | Writes | Must be |
|---|---|---|---|---|
| **Validate** | 2xx | raw, `mig.code_map`, `mig.v_rejected` | `mig.error` only | read-only on data, repeatable |
| **Transform** | 3xx | raw, `mig.code_map`, `mig.error` | stg | deterministic, `TRUNCATE` + rebuild |
| **Reconcile / verify** | 4xx, 6xx | two layers: raw + stg (4xx), stg + target (6xx) | `mig.reconciliation` | read-only, compares *independently computed* numbers |
| **Gate** | x90, 780 | `mig.*` | nothing | `RAISE EXCEPTION` when a check fails or a threshold is broken |
| **Load** | 5xx | stg, `mig.id_map`, `mig.run_phase`, `mig.checkpoint`, deleted keys in raw | target, `mig.id_map`, `mig.checkpoint` | idempotent upserts, in FK order, batched where big; deletes only rows the migration created |
| **Profile** | 0xx in `00_assess/` | src | nothing | read-only (`SET TRANSACTION READ ONLY`) |

> [!NOTE]
> Each file runs in **one transaction** (`psql -1`). A failing statement leaves nothing half-done.\
> The exception is files named `*_batched*`, which commit per batch themselves.

#### >> Reads and writes per phase

| Phase / sub-phase | Reads | Writes |
|---|---|---|
| Report (`run.sh report`) | `mig.run`, `mig.run_phase`, `mig.error`, `mig.reconciliation` | nothing (prints to the screen) |
| The old system (`source/`) | — | database `legacy_shop`: `legacy.customers`, `legacy.products`, `legacy.order_lines` (`legacy_shop.sql` creates them, `legacy_changes.sql` changes them) |
| Setup (`run.sh setup`) | the table definitions of `legacy_shop` (`IMPORT FOREIGN SCHEMA`) | schemas `raw`, `stg`, `mig`, `src`; `src.*` (foreign tables); the `mig.*` control tables, `mig.v_rejected` and functions; `mig.code_map`; `public.*` (target tables + `public.country` rows) |
| 0 ASSESS (`run.sh assess`) | `src.*` | nothing (prints to the screen) |
| 1 EXTRACT | `src.*` | `raw.customers`, `raw.products`, `raw.order_lines`; `mig.watermark` |
| 2 VALIDATE → GATE 1 | `raw.v_*`, `mig.code_map`, `mig.v_rejected` (dependency check, gate), `mig.reconciliation` (gate) | `mig.error` only (plus the gate's checks in `mig.reconciliation`) |
| 3 TRANSFORM | `raw.v_*`, `mig.v_rejected`, `mig.code_map` | `stg.*` |
| 4 RECONCILE → GATE 2 | `raw.v_*`, `stg.*`, `mig.v_rejected`, `mig.reconciliation` (gate) | `mig.reconciliation` |
| 5 LOAD | `stg.*`, `mig.id_map`, `raw.v_deleted_*`, `mig.run_phase` (guard), `mig.checkpoint` (resume point) | `public.*`, `mig.id_map`, `mig.checkpoint` |
| 6 VERIFY → GATE 3 | `public.*`, `stg.*`, `mig.id_map`, `raw.v_*`, `mig.run` (run kind for the delta checks), `mig.reconciliation` (gate) | `mig.reconciliation` |
| 7 CUTOVER: Delta run (`run.sh delta`) | `legacy.*`; `src.*`, `mig.watermark`, `raw.v_*`; then as 2–6 | `legacy.*` (the simulated changes); `raw.*` (new batch + tombstones), `mig.watermark`; then as 2–6, the load also applying the deletes |
| 7 CUTOVER: Cutover (`run.sh cutover`) → GATE 4 | `mig.run`; `src.*`, `mig.watermark`, `raw.v_*`; then as 2–6; `public.*` (smoke test); `pg_db_role_setting`, `mig.run_phase`, `mig.reconciliation` (go/no-go) | setting of database `legacy_shop` (freeze; reset by `unfreeze`); `raw.*`, `mig.watermark`; then as 2–6; `public.orders`, `public.order_line` (smoke test, undone again); `mig.reconciliation` |
| 7 CUTOVER: Rollback (`run.sh rollback`) | `mig.id_map` | deletes from `public.order_line`, `public.orders`, `public.customer` (+ `public.address` by cascade), `public.product`, `public.category`; empties `mig.id_map`, `mig.checkpoint`; `mig.run` (status `ROLLED_BACK`) |
| 8 CLEANUP: Archive and cleanup (`run.sh archive`, `run.sh cleanup`) | `mig.*` | files `archive/<timestamp>/report.txt`, `mig_<table>.csv`; drops `raw`, `stg`, `src`, the server `legacy_srv`, `mig.load_orders()`; `mig` stays |

#### >> `Gates:` How a exceptions stop the run

Phases **2 VALIDATE**, **4 RECONCILE**, **6 VERIFY** and **7 CUTOVER** (go/no-go) end with a gate. When one fails:
1. `mig.gate()` raises an exception.
2. psql runs with `ON_ERROR_STOP=1`, so it exits with an error code.
3. `run.sh` sees the failed file, marks the phase `FAILED` in `mig.run_phase`, and exits (`exit 1`). The next phase never starts.
4. As a second safety net, the load phase itself checks too: `05_load/500_pre_load.sql` calls `mig.require_phase()` and refuses to start unless validate, transform and reconcile are `DONE` in this run.

The four gates: **GATE 1** validate (`290`), **GATE 2** reconcile (`490`), **GATE 3** verify (`690`), and at cutover **GATE 4** go/no-go (`780`).

#### >> `Validate, reconcile, verify`: what each one proves

| | 2 VALIDATE | 4 RECONCILE | 6 VERIFY |
|---|---|---|---|
| **Purpose** | is the source data good? | did the transform data lose anything? | did the load deliver it, and is the result right? |
| **Looks at** | raw, against the **rules** | staging **vs raw** | production **vs staging**, plus known facts |
| **Proves** | every source record is either good enough to migrate or quarantined with a reason, and there aren't too many rejects | every source record is in staging, merged or rejected, and amounts and quantities still match | the load delivered staging completely and unchanged, with valid constraints and the expected business results |
| **Catches** | **bad source data**: e-mail without `@`, impossible date, unknown status code | **bugs in our transform rules**: a join that drops orders, wrong parsing of amounts, faulty dedupe | **bugs in the load**: a lost batch, a wrong FK through the id map, an upsert that skips a change, a missing delete |
| **Input** | `raw.v_*`, `mig.code_map`, the rule functions (`003_helpers.sql`) | `raw.v_*`, `stg.*`, `mig.v_rejected` (validate's rejects) | `public.*`, `stg.*`, `mig.id_map`, `raw.v_*` (deleted keys) |
| **Output** | `mig.error` (REJECT / WARN), `mig.v_rejected` | checks in `mig.reconciliation` | checks in `mig.reconciliation` |
| **Gate** | 1: reject rate ≤ 5 % | 2: all counts, totals and fingerprints match | 3: production is right |
| **Production touched?** | no | no | yes, verify comes after the load |

#### >> Report (`run.sh report`)

All phases use it: `./run.sh report` (or `.\run.ps1 report`) is **read-only**. It runs four queries against the `mig` audit tables and prints them.

| Reads | Writes |
|---|---|
| `mig.run`, `mig.run_phase`, `mig.error`, `mig.reconciliation` | nothing (prints to the screen) |

**1. Runs**: every run so far, not only the current one. The status is `RUNNING`, `DONE`, `FAILED` (a phase or gate failed) or `ROLLED_BACK`.
```
 run_id | kind  | status | started_at          | finished_at
      1 | full  | DONE   | 2026-09-25 15:24:18 | 2026-09-25 15:24:46
      2 | delta | DONE   | 2026-09-25 15:24:48 | 2026-09-25 15:25:15
```

**2. Phases of the current run**: which phases ran, their result, and how long each took. After a failure you see exactly where the run stopped, e.g. `02_validate | FAILED`, with no later phases listed.
```
 phase         | status | seconds
 01_extract    | DONE   |     1.2
 02_validate   | DONE   |     2.3
```

**3. Findings of the current run**: the quarantine (`mig.error`), grouped by entity, severity and rule, counting **records** (distinct source keys), not individual errors. This is the overview for **the data owners**: *what* was rejected and *why*. The individual records (key, column, raw value) are in `mig.error` itself.
```
 entity   | severity | rule                | records
 customer | REJECT   | email_format        |       8
 customer | WARN     | phone_format        |     500
```

**4. Checks of the current run**: every check from validate, reconcile and verify, with the values compared (`mig.reconciliation`).
```
 phase     | check_name                                     | ok | expected | actual
 reconcile | customers: raw = survivors + merged + rejected | t  | 2000     | 2000
 verify    | duplicate 1901 merged into customer 1          | t  | 1        | 1
```

### Before the phases

#### >> The old system (`source/`)

Database `legacy_shop` is a denormalized e-shop with 2,000 customers, 300 products and 6,000 orders (15,000 order lines, with the order header repeated on every line).

| Reads | Writes |
|---|---|
| — | database `legacy_shop`: `legacy.customers`, `legacy.products`, `legacy.order_lines` (`legacy_shop.sql` creates them, `legacy_changes.sql` changes them) |

Problems are planted deterministically, so every number in the checks is reproducible:

| Data | Planted problems |
|---|---|
| Customers | Duplicates (same e-mail in different case), e-mails without `@`, two date formats plus an impossible date (`31.02.2021`), countries as free text (`Serbia`/`srbija`/`RS`) plus one nobody can map (`Atlantis`), phones in three formats, unparseable addresses, one-word names |
| Products | Prices with decimal comma or point, an unparseable price (`n/a`), a category spelled 7 ways |
| Order lines | Legacy status codes plus an unknown one, quantity `0` and `two`, orders of non-existing customers, an order whose header differs between its lines |

> [!NOTE]
> `source/legacy_changes.sql` is the input of the **delta** run (`./run.sh delta`). 
> <br> It simulates changes in the old system still being used after the initial load: an e-mail change, a fixed record, a new customer, a shipped order, a new order, and three deletes (an order, an order line, a customer with their orders).

#### >> Setup (`run.sh setup` -> all scripts from `00_setup/`)

Before phase **0 ASSESS**: prepares everything the migration pipeline needs. All scripts are idempotent, so `./run.sh setup` can be re-run at any time.

| Reads | Writes |
|---|---|
| the table definitions of `legacy_shop` (`IMPORT FOREIGN SCHEMA`) | schemas `raw`, `stg`, `mig`, `src`; `src.*` (foreign tables); the `mig.*` control tables, `mig.v_rejected` and functions; `mig.code_map`; `public.*` (target tables + `public.country` rows) |

| File | Contents |
|---|---|
| `001_schemas.sql` | Schemas `raw`, `stg`, `mig`, `src`; `postgres_fdw` connection to `legacy_shop`; the old tables imported as foreign tables into `src` |
| `002_control_tables.sql` | The `mig` control tables and the view `mig.v_rejected` (see [Mig. Tables](#mig-tables)) |
| `003_helpers.sql` | Run/phase/check/gate functions (`mig.new_run()`, `mig.check()`, `mig.gate()`, ...) and the migration rules (`mig.parse_date()`, `mig.normalize_phone()`, ...) |
| `004_code_maps.sql` | Value mappings: countries and order statuses |
| `005_target_schema.sql` | The new model (production) in `public`, with its constraints |

> [!NOTE]
> Compared with the [standard phases](#-the-standard-phases): the code maps are created in setup instead of in transform (validation needs them to recognize unknown codes), and `240_chk_dependencies.sql` propagates rejects from parents to children.

### 0 ASSESS

#### >> Assess (`run.sh assess` -> all scripts from `00_assess/`)

Phase **0 ASSESS**: profile the old system **before** any rule is written. The profiling result is the input for the validation rules, the code maps and the planning (volumes, batching, delta strategy).
- **Read-only:** every file starts with `SET TRANSACTION READ ONLY`, reads the source through the `src` foreign tables, and stores nothing.
- **Not logged as a run:** there's no `mig.run` yet when it's used, and it isn't part of `./run.sh all`. Run it once at the start, and again when the source changes.

| Reads | Writes |
|---|---|
| `src.*` | nothing (prints to the screen) |

| File | Finds | Leads to |
|---|---|---|
| `010_volumes.sql` | Row counts, oldest/newest `updated_at` (products have none!), lines per order, missing values per column | Batch sizes, delta strategy, NOT NULL decisions |
| `020_formats.sql` | Value **shapes** (digit → `9`, letter → `A`): two date formats, three phone formats, decimal comma vs point, `qty = 'two'`; e-mail quality; address and name structure | The parse rules in `003_helpers.sql`, the checks in `210_chk_structure.sql` |
| `030_keys_and_relations.sql` | Duplicates by normalized e-mail, orphan order lines, orders whose header differs between lines | Deduplication (`310`), integrity checks (`220`) |
| `040_value_lists.sql` | Every country, status code, category spelling and active flag, with counts | The code maps (`004_code_maps.sql`): one decision per value |

> [!IMPORTANT]
> In a real project the profiling result is reviewed with **the business owners** of the data, and many rules (which duplicates to merge, which unknown codes to reject) are decided there.
> <br> Technically, profiling tools are used (dbt tests, Great Expectations, AWS Glue DataBrew), and volumes and growth rates decide the strategy: big bang, initial + delta, or CDC.

### 1 EXTRACT to 6 VERIFY

> [!TIP]
> `./run.sh all` runs these phases in order, one folder each (`01_extract/` … `06_verify/`). What each script does is described per phase below (and briefly in [Project Layout](#project-layout)), what each phase reads and writes in [Reads and writes per phase](#-reads-and-writes-per-phase), the rules per script type in [What each type of script does](#-what-each-type-of-script-does), and the result in [Expected result of a full run](#expected-result-of-a-full-run).
>
> A single phase can be run again within the current run (`./run.sh validate`, `./run.sh transform`, ...), e.g. after fixing a rule. Each phase is recorded in `mig.run_phase` as `01_extract` … `06_verify`.

**How the data moves through the stages, per entity:**

| Entity | Source (`src`) | Raw (1 EXTRACT) | Staging (3 TRANSFORM) | Target (5 LOAD) |
|---|---|---|---|---|
| Customers | `src.customers` | `raw.customers` → view `raw.v_customers` | `stg.customer` (one row per survivor), `stg.customer_alias` (every accepted legacy number → its survivor), `stg.address` | `public.customer`, `public.address` |
| Products | `src.products` | `raw.products` → `raw.v_products` | `stg.category`, `stg.product` | `public.category`, `public.product` |
| Orders | `src.order_lines` (header repeated on every line) | `raw.order_lines` → `raw.v_order_lines` | `stg.orders` (one header per order), `stg.order_line` | `public.orders`, `public.order_line` |

> [!NOTE]
> Along the way: 
> <br> **1 EXTRACT** writes `mig.watermark` (how far the extract has read)
> <br> **2 VALIDATE** writes findings to `mig.error` (and its gate's checks to `mig.reconciliation`) 
> <br> **4 RECONCILE** and **6 VERIFY** write checks to `mig.reconciliation`
> <br> **5 LOAD** writes `mig.id_map` (legacy key → new id) and `mig.checkpoint` (progress of the batched order load)
> <br>  Every phase is also recorded in `mig.run_phase` by `run.sh`

#### >> 1 EXTRACT (`01_extract/`)

Copies the old system **1:1** into `raw`, without changing anything.

| Reads | Writes |
|---|---|
| `src.*` (foreign tables → `legacy_shop`) | `raw.customers`, `raw.products`, `raw.order_lines`; `mig.watermark` |

- `110_raw_tables.sql` creates the raw tables. Every column is `text`, so dirty values can't make the extract fail; they're found by validation instead. Every row gets `_batch_id` (the run), `_loaded_at`, and `_deleted` (tombstone, set only by the delta). The file also creates the views:
  - `raw.v_*`: the latest live version per key;
  - `raw.v_deleted_*`: keys deleted in the source.
- `120_load_raw.sql` runs the **full extract** in one transaction, so all three tables come from one consistent snapshot of the old system. It sets the watermarks (latest `updated_at` per table).
  - It is skipped when `raw` already holds a full extract from an earlier run: later changes come in through the delta (`710`).
  - Re-running it in the same run replaces its own batch.

**Connections**
- **Needs** setup (`src`, the `mig` tables) and a run (`mig.new_run('full')`, started by `run.sh`).
- `mig.watermark` is the starting point of the delta (`710`) and is checked again at the go/no-go (`780`).
- `raw` keeps every extracted version until **8 CLEANUP** drops it.
- **Feeds** 2 VALIDATE, 3 TRANSFORM and 4 RECONCILE (`raw.v_*`), 5 LOAD and 6 VERIFY (deleted keys, `raw.v_deleted_*`). **Every later phase reads raw only through these views**, never the base tables. That's why new batches (delta) and tombstones (deletes) work without changing any later script.
- **No gate of its own:** the copy is 1:1, from one consistent snapshot in one transaction. Its result is checked by 2 VALIDATE (rules) and 4 RECONCILE (staging vs raw).

> [!IMPORTANT]
> In a real project the old system is another server, often another engine. The extract then runs through an export file, an ETL / CDC tool, or the matching foreign data wrapper (`oracle_fdw`, `tds_fdw`, `mysql_fdw`), ideally against a read replica or outside business hours, so it doesn't slow down the **users**.
> <br> Technically, it is decided between full, incremental or CDC extract, from a consistent point (snapshot, LSN / SCN), often into files (CSV / Parquet) with a row count and checksum per file, and with character set conversion (e.g. Windows-1250 to UTF-8).

#### >> 2 VALIDATE (`02_validate/`) → GATE 1

Checks every raw record against the rules and **quarantines** what can't be migrated. It changes no data.

**Purpose:** is the source data good?\
**Proves:** every source record is either good enough to migrate or quarantined with a reason, and there aren't too many rejects.\
**Catches:** **bad source data**: e-mail without `@`, impossible date, unknown status code.

> [!WARNING] **Never fix data in `raw`.** 
> <br> Raw is a 1:1 copy of the source: a fix there no longer matches the source, is overwritten by the next extract or delta, hides the difference from reconcile, and breaks the audit trail. 
> <br> A finding is fixed in one of three places:
> - **a wrong record** (e-mail without `@`, impossible date): in the **source**, by **the data owners** through the old system (not by **the migration**'s scripts); the next delta brings the fix ([feedback loop](#-delta-run-runsh-delta));
> - **a missing or wrong rule** (unknown country spelling, wrong amount parser): in the **rules** (`003_helpers.sql`, `004_code_maps.sql`, `3xx`), then rerun;
> - **a record the source can't fix** (old system read-only, record too old): a documented **correction rule or mapping** in the migration, agreed with **the data owners**.

| Reads | Writes |
|---|---|
| `raw.v_*`, `mig.code_map`, `mig.v_rejected` (dependency check, gate), `mig.reconciliation` (gate) | `mig.error` only (plus the gate's checks in `mig.reconciliation`) |

| File | Rules (rule name in `mig.error`) | Severity |
|---|---|---|
| `200_reset.sql` | deletes this run's findings, so re-running doesn't add duplicates | — |
| `210_chk_structure.sql` | `email_format`, `date_format`, `amount_format`, `qty_format` | REJECT |
| | `phone_format`, `address_format` | WARN: migrated without that value (instead used NULL / missing) |
| `220_chk_integrity.sql` | `orphan_customer`, `orphan_product`, `inconsistent_header` (one order, different headers on its lines) | REJECT |
| `230_chk_business.sql` | `unmapped_country`, `unmapped_status`, `qty_not_positive`, `price_not_positive` | REJECT |
| `240_chk_dependencies.sql` | `customer_rejected`, `product_rejected`: orders of rejected customers / products are rejected too | REJECT |
| `290_gate_validate.sql` | **GATE 1**: reject rate ≤ 5 % per entity | — |

**Connections**
- The parsing rules (`mig.parse_date()`, `mig.normalize_phone()`, ...) and the code maps are the **same** ones transform uses (`003_helpers.sql`, `004_code_maps.sql`). Validation and transformation can't disagree about what is valid.
- Its output is the view **`mig.v_rejected`** (the rejected keys of the current run). Transform excludes exactly these keys, and reconcile counts them. `WARN` findings aren't in it: the record is migrated, only the value is dropped.
- The **5 LOAD** refuses to start unless `02_validate` is `DONE` in this run (`mig.require_phase()`).
- A record fixed in the source comes back through the next delta and is validated again: the [feedback loop](#-delta-run-runsh-delta).
- **Reads** `raw.v_*` from 1 EXTRACT. It is repeatable: `200_reset.sql` replaces this run's findings.
- **GATE 1** (`290`) writes its checks to `mig.reconciliation`. If it fails, `run.sh` marks `02_validate` as `FAILED` and stops: 3 TRANSFORM never starts.
- `mig.error` is shown by the report, archived by **8 CLEANUP**, and kept in `mig` as the audit trail.

> [!IMPORTANT]
> In a real project the validation rules, their severity (REJECT or WARN) and the gate thresholds are agreed with **the business owners** of the data. The quarantine list goes back to them after every run, so they can fix the records in the source.
> <br> Technically, the rules are often stored as data (a rule table) instead of code, with thresholds per rule, and with samples of failing records for **the data owners**.

#### >> 3 TRANSFORM (`03_transform/`)

Turns the raw copy into **typed, cleaned rows in the target shape**: parses dates and amounts, normalizes e-mails and phones, maps codes, merges duplicate customers, and splits names, addresses and order headers. <br> The rows are still keyed by the **legacy** keys (`cust_no`, `sku`, `order_no`); new ids only appear in the load.

| Reads | Writes |
|---|---|
| `raw.v_*`, `mig.v_rejected`, `mig.code_map` | `stg.*` |

| File | Builds | From |
|---|---|---|
| `300_stg_tables.sql` | creates `stg.*` and **truncates** them: staging is rebuilt from scratch every run | — |
| `310_stg_customer.sql` | `stg.customer_alias`: every accepted legacy number → its survivor (same normalized e-mail = same person, the oldest account survives). `stg.customer`: one row per survivor, a missing phone taken from a duplicate, country mapped | `raw.v_customers` minus rejected |
| `320_stg_address.sql` | `stg.address`: free text → street / zip / city; unparseable addresses (WARN) get no row | `stg.customer` + `raw.v_customers` |
| `330_stg_product.sql` | `stg.category`: one per normalized spelling, the most common spelling as name. `stg.product`: price → cents | `raw.v_products` minus rejected |
| `340_stg_order.sql` | `stg.orders`: one header per order, customer resolved to the **survivor**, status mapped. `stg.order_line`: only the lines of staged orders | `raw.v_order_lines` minus rejected, `stg.customer_alias` |
| `390_stg_analyze.sql` | statistics and row counts | — |

**Connections**
- The order inside the phase matters: `stg.customer_alias` before `stg.orders` (orders of merged duplicates move to the survivor), `stg.customer` before `stg.address`.
- The phase has **no gate of its own**. It is checked by **4 RECONCILE** against raw.
- Because staging is rebuilt every run, fixing a rule means changing it and re-running transform and reconcile. Nothing else has to be undone.
- `stg.*` is the input of **5 LOAD** and the reference of **6 VERIFY**. 
- **8 CLEANUP** drops it.
- **Reads** `raw.v_*` from 1 EXTRACT, the rejects of 2 VALIDATE (`mig.v_rejected`) and the code maps from setup.
- **5 LOAD** refuses to start unless `03_transform` is `DONE` in this run (`mig.require_phase()`).

> [!IMPORTANT]
> In a real project every transformation is written down first, in a source-to-target mapping document (which column becomes which, by which rule), and signed off by **the business**: for example which duplicates are merged and which account survives.
> <br> Technically, the key strategy is decided (keep legacy ids, a new sequence / identity, or UUIDs), timestamps are converted to UTC, and duplicates of names and addresses are found by fuzzy matching, often in an MDM tool.

#### >> 4 RECONCILE (`04_reconcile/`) → GATE 2

Proves that staging is a **complete and correct** image of raw, minus the documented rejects. Nothing has touched production yet.

**Purpose:** did the transform data lose anything?\
**Proves:** every source record is in staging, merged or rejected, and amounts and quantities still match.\
**Catches:** **bugs in our transform rules**: a join that drops orders, wrong parsing of amounts, faulty dedupe.

| Reads | Writes |
|---|---|
| `raw.v_*`, `stg.*`, `mig.v_rejected`, `mig.reconciliation` (gate) | `mig.reconciliation` |

| File | Checks |
|---|---|
| `410_rec_counts.sql` | Counts per entity: `raw = survivors + merged + rejected` (customers), `raw = staged + rejected` (products, orders), `raw = staged lines + lines of rejected orders`; no rejected key reached staging |
| `420_rec_totals.sql` | Order amount total and product price total: computed **independently** from raw (with its own parsing) vs staged. Per-order totals compared in both directions |
| `430_rec_fingerprint.sql` | md5 fingerprints over sorted values: order lines (order, line, sku, qty), distinct accepted e-mails |
| `490_gate_reconcile.sql` | **GATE 2**: every check above passed |

**Connections**
- It checks **3 TRANSFORM** against **1 EXTRACT**, using the rejects of **2 VALIDATE**. Every source record has to be accounted for exactly once: staged, merged into a survivor, or rejected.
- It is the **last free stop**: a failed check here costs only a fix of the **rule**, never the tables (a `3xx` file → rerun 3 and 4; a helper or code map in `00_setup/` → `setup`, then rerun 2–4).
- **GATE 2** (`490`) reads its checks from `mig.reconciliation`. If it fails, `run.sh` marks `04_reconcile` as `FAILED` and stops: 5 LOAD never starts, production stays untouched. As a second safety net, the load also refuses to start unless `03_transform` and `04_reconcile` are `DONE` in this run.
- Its checks stay in `mig.reconciliation`: shown by the report, and required again by the go/no-go (`780`) of the cutover run.

> [!IMPORTANT]
> In a real project the reconciliation report is part of the sign-off: **finance** or **the data owners** confirm that counts and totals match before anything is loaded, and **auditors** may ask for it later.
> <br> Technically, the source system delivers control totals (counts, sums, hash totals) to compare against, and a full compare or sampling is chosen; diff tools help (data-diff, AWS DMS data validation).

#### >> 5 LOAD (`05_load/`)

The **only phase that writes production**. It writes in foreign-key order, with idempotent upserts (only diff, instead of full inserts).

> [!NOTE]
> **It is not just a copy of staging:**\
> The load contains **no business rules**: every value was already cleaned, converted and mapped in staging.\
> But staging and production differ in their **keys**, and the load must be **safe to repeat**: new ids instead of legacy keys, foreign keys through the id map, foreign-key order, upsert instead of insert, batches with checkpoint, deletes, guard with `gates`, statistics with `ANALYZE`.\
> **Load decides how the data gets into production safely.** It holds mechanics only: ids, order, upserts, batches. That's why a reconcile failure is fixed in the transform, never in the load.

**Idempotent reruns** 
- A rerun finds the same rows by the same keys and only fixes what differs:
  - **A key from the old system on every target table** (`UNIQUE` on `legacy_cust_no`, `sku`, `order_no`, `(order_id, line_no)`, …): rows are found by these keys, never by generated ids.
  - **Upsert instead of insert:** `INSERT … ON CONFLICT (key) DO UPDATE … WHERE … IS DISTINCT FROM …`. A new row is inserted, a changed row updated, an unchanged row skipped: no duplicates, no unnecessary writes.
  - **Idempotent bookkeeping:** `mig.id_map` maps each legacy key once (`ON CONFLICT`), `mig.checkpoint` lets a retry continue after the last committed batch, and the deletes (`560`) only touch rows that still exist or are still active.
  - **Deterministic input:** staging is rebuilt from raw the same way every time, so the same source data always leads to the same end state.

**Verification during the load** (light checks that stop errors early; the real proof is 6 VERIFY, after the load)
- **Target constraints** (`NOT NULL`, `CHECK`, FKs, unique keys): the database rejects invalid rows, and the file and the phase fail. Used here.
- **Per-batch counts** (rows read = written + skipped): here only partly, as a checkpoint per batch without counts.
- **Error / reject tables** of ETL tools (SSIS, Informatica) that log failing rows instead of aborting: not needed here, because rejects are found in validate, before the load.
- **Fail-fast thresholds** (stop after N errors): not used here.

**Load optimization at volume** (not needed at demo size; the general rules are in [Large data changes](#large-data-changes-performance-and-safety), the technique in Flyway D15)
- **Indexes:** drop or disable the secondary indexes before a large load and rebuild them afterwards (the place for it: `500_pre_load.sql` / `590_post_load.sql`). Every index makes every insert slower.
- **Triggers:** disable them only in a controlled maintenance window. The migration then has to do their work itself (audit columns, counters, history rows).
- **Foreign keys:** load in FK order (as here), or add the FKs afterwards as `NOT VALID` and `VALIDATE` them separately (Flyway A6).
- **Bulk path:** `COPY` instead of row-by-row inserts, larger batches, and parallel loads over separate key ranges.
- **Session settings:** more memory for the index rebuild (`maintenance_work_mem`).
- **Statistics:** `ANALYZE` after the load, so the first queries get good plans (done here in `590_post_load.sql`).

**Rollback of wrongly loaded data**
- Undoing a bad load is a separate script that uses the recorded ids (`07_cutover/790_rollback.sql`, via `mig.id_map`), not a database transaction rollback.
- Every target table has a natural key from the old system (`legacy_cust_no`, `sku`, `order_no`, …), so every loaded row can be traced back to its source record.
- What rollback can't undo:
  - **Updates:** if a delta's upsert changed a row (e.g. a new e-mail), `790` deletes the whole row; it can't bring back the row as it was before that delta, because the old value was never saved.
  - **Deletes and deactivations from `560`:** they can't be undone either.
  - **Only the last run:** `790` always removes everything the migration loaded, across all runs.

**Output to `mig.id_map`**
- One row per migrated customer (including merged duplicates, mapped to their survivor), category, product and order, as `entity` + `legacy_key` → `new_id` (+ `run_id`), so every production row can be traced back to its source record.

| Reads | Writes |
|---|---|
| `stg.*`, `mig.id_map`, `raw.v_deleted_*`, `mig.run_phase` (guard), `mig.checkpoint` (resume point) | `public.*`, `mig.id_map`, `mig.checkpoint` |

| File | Loads | Notes |
|---|---|---|
| `500_pre_load.sql` | — | **Guard**: `mig.require_phase()` for validate, transform and reconcile; prints the target counts before the load |
| `510_load_customer.sql` | `public.customer` | Upsert by `legacy_cust_no`. Then `mig.id_map` for **every** alias: a merged duplicate maps to its survivor's new id |
| `520_load_address.sql` | `public.address` | `customer_id` resolved through `mig.id_map`, never guessed |
| `530_load_product.sql` | `public.category`, then `public.product` | Parent before child; both recorded in `mig.id_map` |
| `540_load_order_batched.sql` | `public.orders`, `public.order_line` | Batches of 1,000 orders, each with its lines and its `mig.id_map` entries, `COMMIT` + `mig.checkpoint` per batch. A killed load resumes after the last batch. Customer via `mig.id_map`, product via `sku` |
| `560_apply_deletes.sql` | deletes / deactivations | Source deletes (tombstones), only for rows in `mig.id_map` (see [Delta run](#-delta-run-runsh-delta)) |
| `590_post_load.sql` | — | `ANALYZE` of the target tables, counts after the load |

**Connections**
- **One load for every kind of run.** The upserts insert new rows, update only rows that actually changed (`IS DISTINCT FROM`), and skip the rest. 
<br> Running the load again is therefore always safe: the full run, every delta and a rerun after a failure use the same scripts, with no duplicates and no separate delta logic.
- **`mig.id_map` is its main output besides production.** It's used by 6 VERIFY (completeness, business checks), by the delete handling, and by the rollback (`790`: what to remove).
- **After a failure, production is partly loaded:** the committed batches stay. Either rerun to finish the load (`mig.checkpoint` lets it resume after the last batch), or `./run.sh rollback` to empty it (which also empties `mig.checkpoint`).
- **Needs** 2 VALIDATE, 3 TRANSFORM and 4 RECONCILE `DONE` in this run: `500_pre_load.sql` is the second safety net besides the gates.
- **Reads** `stg.*` from 3 TRANSFORM, and the deleted keys (`raw.v_deleted_*`) found by the delta (`710`) for `560`.
- **No gate of its own:** the result is checked by **6 VERIFY**.

> [!IMPORTANT]
> In a real project the target schema is owned by the application's migrations (Flyway / Liquibase), and the load is tuned for volume: secondary indexes dropped and rebuilt, parallel loads, batch sizes measured in rehearsals (see D15).
> <br> Technically, the bulk API is used (`COPY`, `bcp`, `SqlBulkCopy`), with minimal logging (`UNLOGGED` tables, `BULK_LOGGED` recovery model), sometimes loading into new tables and swapping them in (rename / partition exchange), and the sequences are set above the highest loaded id afterwards.
> <br> Run the whole pipeline on a copy of production several times before the real run, and time it. The timing decides whether you need batching or a delta load.

#### >> 6 VERIFY (`06_verify/`) → GATE 3

Checks **production** against staging and against facts known in advance.

**Purpose:** did the load deliver it, and is the result right?\
**Proves:** the load delivered staging completely and unchanged, with valid constraints and the expected business results.\
**Catches:** **bugs in the load**: a lost batch, a wrong FK through the id map, an upsert that skips a change, a missing delete.

| Reads | Writes |
|---|---|
| `public.*`, `stg.*`, `mig.id_map`, `raw.v_*`, `mig.run` (run kind for the delta checks), `mig.reconciliation` (gate) | `mig.reconciliation` |

| File | Checks |
|---|---|
| `610_ver_counts_totals.sql` | `stg EXCEPT target` per entity: every staged row exists in production **with identical values**; order amount total. One direction only: production may contain more (earlier runs, rows created by **users**) |
| `620_ver_constraints.sql` | All target constraints validated, no orders without lines, every alias in `mig.id_map`, every `mig.id_map` entry points to an existing row |
| `630_ver_business.sql` | Spot checks with known outcomes: customer 1 fully converted, duplicate 1901 merged, a WARN customer without address, rejected customer 500 absent, status mapping, decimal comma, 3 categories. After a delta also the expected changes and deletes |
| `640_ver_deletes.sql` | Every source delete arrived (no deleted line, no empty order, no active deleted customer) |
| `690_gate_verify.sql` | **GATE 3**: the data in production is right |

**Connections**
- It checks **5 LOAD** against **3 TRANSFORM**, and through `630` against **the business**'s expectations.
- After **GATE 3** the full run ends (`mig.end_run('DONE')`). Next comes **7 CUTOVER**: more deltas, then the cutover, whose go/no-go gate requires every check of the final run to have passed, these included.
- **Reads** `public.*` and `mig.id_map` from **5 LOAD**, `stg.*` from **3 TRANSFORM**, and the deleted keys in raw (`640`).
- **GATE 3** (`690`) reads its checks from `mig.reconciliation`. If it fails, `run.sh` marks `06_verify` as `FAILED` and the run ends as `FAILED`. Production is already loaded, so the next step is a fix and rerun, or, if it can't be fixed forward, `./run.sh rollback` (`790`), which removes exactly what `mig.id_map` lists.
- It needs staging, so it can't run after **8 CLEANUP** has dropped `stg`.

> [!IMPORTANT]
> In a real project the automated checks are followed by acceptance tests of **key users** (UAT) on the migrated data. The list of business spot checks is agreed with them, and their sign-off is part of the go-live decision.
> <br> Technically, the application's own regression tests run on the migrated data, performance is tested with production volume, and reports are compared between the old and the new system (e.g. monthly revenue).

### 7 CUTOVER

Phase **7 CUTOVER** is everything after the first full run, up to and including the switch. It contains other phases: each delta and the cutover run repeat phases 2–6.

```
1–6  full run (./run.sh all)                       ← NOT part of 7: the initial load
──────────────────────────── 7 CUTOVER ────────────────────────────
 7a  delta (./run.sh delta)        repeated, the old system still live
       710 delta extract → 2 VALIDATE → 3 TRANSFORM → 4 RECONCILE → 5 LOAD → 6 VERIFY
 7b  cutover (./run.sh cutover)    the final run, one time
       720 freeze old system
       710 final delta extract
       2 VALIDATE → 3 TRANSFORM → 4 RECONCILE → 5 LOAD (last changes) → 6 VERIFY (all data)
       760 smoke test
       780 GO / NO-GO                                  [GATE 4]
 7c  GO:    switch the application to new system (manual, outside the database, old stay frozen)
     NO-GO: unfreeze old system (729), application stays on it live
 7d  safety net: rollback (790), possible until users write to the new system 
      (only empties migrated data from new system, doesn't switch app or unfreeze old system)
```

> [!IMPORTANT]
> The main purpose of repeated deltas is to prepare for the final cutover, making it short.
> <br> The other strategy, has no deltas. You freeze, do one full run, check, and switch.

#### >> Delta run (`run.sh delta`)

Phase **7 CUTOVER**, before the switch: a delta run brings over only what changed in the old system since the previous run: **inserts, updates and deletes**. Meanwhile the old system keeps running (the "initial + delta" cutover strategy). 
<br> `./run.sh delta` does it in three steps:
1. It applies `source/legacy_changes.sql` to the old system (as simulation of postponed user inputs). The file is used **only** by the delta run.
2. It extracts the changes (`07_cutover/710_delta_sync.sql`): changed rows, and tombstones for deleted keys.
3. It runs validate → transform → reconcile → load → verify again, with all gates. The load applies the deletes too (`05_load/560_apply_deletes.sql`).

> [!NOTE]
> The final delta of the cutover (`./run.sh cutover`) works the same way, without step 1.

| Step | Reads | Writes |
|---|---|---|
| 1. `legacy_changes.sql` | `legacy.*` | `legacy.*` (in the old system) |
| 2. `710_delta_sync.sql` | `src.*`, `mig.watermark`, `raw.v_*` | `raw.*` (new batch + tombstones), `mig.watermark` |
| 3. validate … verify | as in [1 EXTRACT to 6 VERIFY](#1-extract-to-6-verify) | as there; the load also applies the deletes (`raw.v_deleted_*` → `public.*`, `mig.id_map`) |

**What `legacy_changes.sql` simulates:** 8 changes. Four are ordinary use of the old system after the initial load, one is a correction of old dirty data, and three are deletes:

> [!IMPORTANT]
> `legacy_changes.sql` changes the **source**, the old system, never `raw.*` directly. It plays the **users** who keep working in the old system.\
> Raw changes only afterwards, when the delta extract (step 2, `710`) copies those changes over.

| # | Change | Represents | Found by | Result in production |
|---|---|---|---|---|
| 1 | Customer 150 changes e-mail | normal business activity | `updated_at` | e-mail updated |
| 2 | Customer 250: `user250.example.com` → `user250@example.com` | **correction of dirty data**: this record (and its orders) was rejected in the full run | `updated_at` | customer and its orders loaded |
| 3 | New customer 2001 | normal business activity | `updated_at` | inserted |
| 4 | Order ORD-000010 is shipped | normal business activity | `updated_at` | status updated |
| 5 | New order ORD-006001 for customer 2001 | normal business activity | `updated_at` | inserted |
| 6 | Order ORD-000020 is purged (all lines) | **delete** | key comparison | order deleted |
| 7 | Line 4 of ORD-000011 is removed | **delete** | key comparison | line deleted, order keeps 3 lines |
| 8 | Customer 301 is deleted together with their orders | **delete** | key comparison | customer deactivated, orders deleted |

> [!IMPORTANT]
> Change 2 is the **feedback loop** of a real migration. A record lands in the quarantine, **the data owners** fix it in the source, and the next delta picks it up. The record then passes validation and is loaded, together with its orders that were rejected because of it.

**How `710_delta_sync.sql` finds changes.** Everything lands in `raw` as a new batch (`_batch_id` = this run):

| Kind of change | How | Tables | In the demo |
|---|---|---|---|
| Inserted / updated rows | `updated_at` after the watermark (`mig.watermark`), which then moves forward | customers, order lines | 3 customers, 5 order lines |
| Inserted / updated rows of a table **without** `updated_at` | compare every source row with its latest version in `raw` | products | 0 products |
| **Deleted rows** | full **key comparison**: a key that is live in `raw` but gone from the source gets a **tombstone** (a copy of its last version with `_deleted = true`) | all three | 1 customer, 5 order lines |

**Deletes, end to end**

| Step | File | What happens |
|---|---|---|
| 1. Detect | `07_cutover/710_delta_sync.sql` | Tombstone for every key that disappeared from the source |
| 2. Hide | `01_extract/110_raw_tables.sql` | `raw.v_*` return the latest version per key and skip tombstoned keys. Validate, transform and reconcile see a deleted row as simply gone, without any change to their scripts. `raw.v_deleted_*` list the deleted keys |
| 3. Apply | `05_load/560_apply_deletes.sql` | Business rules per entity (below), only for rows listed in `mig.id_map`: rows the application created itself are never touched |
| 4. Verify | `06_verify/640_ver_deletes.sql`, `630_ver_business.sql` | No deleted order line or empty order left, no deleted customer still active; the three demo deletes arrived as expected |

What a delete in the old system means in production is a **business decision**, and it differs per entity:

| Deleted in the source | In production | Why |
|---|---|---|
| Order line | deleted | |
| All lines of an order | order deleted (its lines go with `ON DELETE CASCADE`), its `mig.id_map` entry removed | |
| Customer | **deactivated** (`active = false`) | production keeps the order history; a deleted merged duplicate doesn't deactivate its survivor |
| Product | kept, only reported | historic order lines still reference it |

**Only the extract is incremental.** 
<br> After it, validate, transform, reconcile and verify work on the **latest version of all rows** (the `raw.v_*` views), not only the changed ones.

| Level | Meaning | In this demo |
|---|---|---|
| **Delta extract** | read only rows changed or deleted in the source since the last run | ✅ `710_delta_sync.sql`. Customers and order lines by timestamp; products and deletes by a full comparison, which reads every key (or row) of the source |
| **Delta processing** | validate / transform only those rows | ❌ **simplified**: validate, transform and reconcile run over the latest version of all live rows in `raw` |
| **Delta apply** | write only the differences into production | ✅ the loads are upserts with `WHERE ... IS DISTINCT FROM`, so only new or actually changed rows are written, plus the deletes of `560`. The other ~20,000 rows are compared but not touched |

**Why "only the changed rows" isn't enough for processing.** 
<br> The delta brings only customer 250's row; its orders didn't change. 
<br> Processing only the delta rows would migrate the customer but not its orders: a change in one row can change the outcome for other rows that didn't change themselves. 
<br> Real delta processing therefore works on a set of **affected keys**:
- the changed and deleted keys;
- everything that depends on them: children whose parent changed status, duplicates whose survivor changed.

At large volumes, processing only the affected keys is mandatory: recomputing millions of rows after every delta would take too long. 
<br> At demo size, **recomputing** all of staging is simpler and gives the same result.

**Limits of this delta:**
- **Changes without a new `updated_at` are missed.** The delta finds changed customers and order lines only by their `updated_at`. If someone changes a row without updating that column (a manual fix in the database, a job that forgets it), the delta doesn't see the change. Products don't have this problem: they're compared by content.
- **Comparing everything gets slow.** To find deletes and changed products, the delta reads every key or row of the source each time. Fine for this demo, too slow for large tables. Alternatives: a "deleted" flag in the source, an extract of keys only, or CDC (which also sees deletes, in the transaction log).
- **Deleting a surviving customer isn't handled.** Example: customers 1 and 1901 were merged, and 1 is the survivor. If customer 1 is deleted in the source, 1901 becomes the survivor in staging, with the same e-mail. The load then fails, because production still has customer 1 (deactivated) with that e-mail, and e-mails must be unique. A rule to re-merge such pairs would be needed.
- **Deleting a product makes its orders invalid.** The orders' lines point to a product that no longer exists, so validation rejects those orders (`orphan_product`). Production keeps the version loaded earlier, unchanged (see [Limitations](#limitations), item 5).
- **Deactivating isn't erasing.** A deleted customer is only set to `active = false`; the name, e-mail and phone stay. For a GDPR erasure request, those personal columns must also be anonymized.

#### >> Cutover (`run.sh cutover`)

Phase **7 CUTOVER**: the switch from the old system to the new one: the last step of the "initial + delta" strategy. `./run.sh cutover` is one run (`kind = 'cutover'`) with these phases:

| Step | Reads | Writes |
|---|---|---|
| 1. `720_freeze_source.sql` | `mig.run` | setting of database `legacy_shop` (`default_transaction_read_only`); open sessions ended |
| 2. `710_delta_sync.sql` | `src.*`, `mig.watermark`, `raw.v_*` | `raw.*`, `mig.watermark` |
| 3. validate … verify | as in [1 EXTRACT to 6 VERIFY](#1-extract-to-6-verify) | as there |
| 4. `760_smoke_test.sql` | `public.customer`, `public.orders`, `public.order_line`, `public.product` | `public.orders`, `public.order_line` (undone again); `mig.reconciliation` |
| 5. `780_go_no_go.sql` | `pg_db_role_setting`, `src.*`, `mig.watermark`, `mig.run_phase`, `mig.reconciliation` | `mig.reconciliation` |
| NO-GO: `729_unfreeze_source.sql` | — | setting of database `legacy_shop` (reset) |

| # | Phase | File | What happens |
|---|---|---|---|
| 1 | `07_freeze_source` | `720_freeze_source.sql` | Refuses without a successful full run. Then `ALTER DATABASE legacy_shop SET default_transaction_read_only = on` and disconnects open sessions: the old system can't change anymore |
| 2 | `07_delta_sync` | `710_delta_sync.sql` | The **final delta**: everything that changed (or was deleted) since the last run |
| 3 | `02_validate` … `06_verify` | as in every run | All three gates again |
| 4 | `07_smoke_test` | `760_smoke_test.sql` | The new system answers what the application asks on day one: login lookup by e-mail, order history, product lookup, and a **write**: a new order for a migrated customer, undone right after. The write catches identity / sequence collisions with migrated ids, missing defaults and constraints the application would trip over |
| 5 | `07_go_no_go` | `780_go_no_go.sql` | **GATE 4**, the go-live decision. It checks that the source is frozen, nothing changed after the final delta, every phase of this run is `DONE`, and every check passed (validate, reconcile, verify, smoke). It prints every criterion and stops on any failure |

**GO:** switch the application to the new database (connection string / DNS). That step is outside the database and therefore not scripted. Keep the old system frozen as a read-only fallback for the agreed period, then `./run.sh cleanup`.

**NO-GO**, or any phase failing on the way: `./run.sh unfreeze` (`729_unfreeze_source.sql`). The old system stays the live system, and the cutover is rehearsed again later.

> [!WARNING]
> `default_transaction_read_only` is a guard, not security: a session could switch it off again. In real life, stop the old application first, and revoke write privileges for a strict freeze.

> [!NOTE]
> While frozen, `./run.sh delta` fails (`legacy_changes.sql` can't write). That is the freeze working.\
> The downtime of the old system is phases 1–5. Rehearsals measure exactly that window, and the final delta is small if deltas ran regularly before the cutover.

> [!IMPORTANT]
> In a real project the cutover follows a written runbook with timed steps and owners. It is rehearsed end to end (dress rehearsal) on a production copy, the go/no-go is a meeting of all **stakeholders**, and **users** are informed about the freeze in advance.
> <br> Technically, a backup or snapshot right before go-live is the real rollback point, the old system's jobs and interfaces are stopped, integrations are re-pointed, and the switch happens through the connection string, DNS or a feature flag.

#### >> Rollback (`run.sh rollback`)

Undoing a bad load is a separate script that uses the recorded ids, not a database transaction rollback. 
<br> Every target table has a natural key from the old system (`legacy_cust_no`, `sku`, `order_no`, …), so every loaded row can be traced back to its source record.
<br> Rollback uses **`mig.id_map`** as the list of everything the migration put into production. Every load script records each row it writes there, as *entity + legacy key → new id*.

> [!TIP]
> Not only for the cutover: `./run.sh rollback` can be used any time after a load has written to production (after a full run, a delta, or between rehearsals), as long as no **users** work in the new system yet.

| Reads | Writes |
|---|---|
| `mig.id_map` | deletes from `public.order_line`, `public.orders`, `public.customer` (+ `public.address` by cascade), `public.product`, `public.category`; empties `mig.id_map`, `mig.checkpoint`; `mig.run` (status `ROLLED_BACK`) |

Phase **7 CUTOVER**, the NO-GO path: `07_cutover/790_rollback.sql` is a single transaction (`psql -1`).
<br> **What `790_rollback.sql` does, in one transaction:**
1. **Delete in foreign-key order, children first**, only rows whose id is in `mig.id_map`.
2. **Clear the bookkeeping**: `mig.id_map` and `mig.checkpoint` are emptied, and every run in `mig.run` is marked `ROLLED_BACK`.
3. It prints the target's row counts afterwards (all 0 in the demo).

> [!WARNING]
> **What rollback can't undo:**
> - **Updates:** if a delta's upsert changed a row (e.g. a new e-mail), `790` deletes the whole row; it can't bring back the row as it was before that delta, because the old value was never saved.
> - **Deletes and deactivations from `560`:** they can't be undone either.
> - **Only the last run:** `790` always removes everything the migration loaded, across all runs.

> [!NOTE]
> Everything **not** in `mig.id_map` stays untouched. That covers the reference rows created by setup (`country`), and in a real system, rows the application created itself. If anything fails, the whole transaction rolls back and production is unchanged.

### 8 CLEANUP

#### >> Archive and cleanup (`run.sh archive`, `run.sh cleanup`)

Phase **8 CLEANUP** after the go-live has been accepted and the retention period is over:

| Step | Reads | Writes |
|---|---|---|
| 1. archive (`run.sh`) | `mig.*` | files `archive/<timestamp>/report.txt`, `mig_<table>.csv` |
| 2. `810_drop_raw_stg.sql` | — | drops `raw`, `stg`, `src`, the server `legacy_srv`, `mig.load_orders()`; `mig` stays |

1. **Archive** (`./run.sh archive`, also the first step of `cleanup`) writes the audit trail as files into `archive/<timestamp>/`, outside the database:
   - `report.txt`: the [report](#-report-runsh-report).
   - `mig_<table>.csv`: every [control table](#mig-tables) (`run`, `run_phase`, `error`, `reconciliation`, `id_map`, `code_map`, `watermark`, `checkpoint`), via `COPY ... TO STDOUT`.

   These files go into the project documentation, or to the **auditor** and **the data owners** (e.g. the list of rejected records with their raw values).
2. **Drop** (`08_cleanup/810_drop_raw_stg.sql`): schemas `raw`, `stg` and `src`, and the connection to the old system. The `mig` schema stays in the database as the audit trail.

> [!NOTE]
> If the archive fails, nothing is dropped.

> [!IMPORTANT]
> In a real project the retention period for raw, staging and the archive is set by **legal and compliance** requirements, the archive goes into the project's document management, and cleanup ends with decommissioning the old system.
> <br> Technically, a final read-only backup of the old database is kept for the retention period, and the connections, credentials and access to the old system are removed.

---

## Running the demo

**Requirements:** Docker with Compose. Use `run.sh` (Git Bash, Linux, macOS) or `run.ps1` (PowerShell); both take the same commands. The database listens on `localhost:5435` (demo/demo) for GUI clients.

```bash
./run.sh assess       # optional first step: profile the old system (read-only)
./run.sh all          # creates the old system on first use, then setup + phases 01..06
./run.sh report       # runs, phases, findings per rule, every check with expected/actual
```

The whole lifecycle, in the order it was **tested** (all commands also work with `.\run.ps1`):

```bash
./run.sh source       # (re)create the old system with its dirty data
./run.sh reset        # drop the new system: start from scratch
./run.sh assess       # 0 ASSESS: profiling, read-only
./run.sh all          # 1-6: full run, GATES 1-3                          ~27 s
./run.sh delta        # 7: changes in the old system -> delta run          ~26 s
./run.sh cutover      # 7: freeze, final delta, smoke test, GATE 4 -> GO   ~30 s
./run.sh archive      # 8: report + control tables as files
./run.sh cleanup      # 8: archive, then drop raw / stg / src
```
Times are from a test run on a laptop: AMD Ryzen 5 5600H (6 cores / 12 threads), 16 GB RAM, NVMe SSD, Windows 11 with Docker Desktop on WSL2. `./run.sh report` shows the duration of every phase.

### Expected result of a full run

| | Source | Rejected | Merged duplicates | Production |
|---|---|---|---|---|
| Customers | 2,000 | 19 | 97 | 1,884 (+1,853 addresses) |
| Products | 300 | 2 | — | 298 (3 categories from 7 spellings) |
| Orders | 6,000 | 203 | — | 5,797 (14,432 lines) |

Plus 540 `WARN` findings: customers migrated without an unparseable phone number or address. Every number is checked by the gates. `./run.sh report` shows them all.

### Walkthroughs

**1a. The validate gate stops bad data.** Remove one country mapping, and 15 % of the customers can't be mapped:
```bash
docker compose exec -T postgres psql -U demo -d shop -c "DELETE FROM mig.code_map WHERE old_code = 'srbija'"
./run.sh validate     # FAIL reject rate customer <= 5 %  -> GATE validate: 2 check(s) failed
./run.sh load         # refuses: "Phase 02_validate has not completed successfully"

./run.sh setup        # restores the mapping (setup is idempotent)
./run.sh validate && ./run.sh transform && ./run.sh reconcile && ./run.sh load && ./run.sh verify
```

**1b. The reconcile gate stops a bad rule.** A bug in the amount rule: the decimal comma is dropped instead of replaced (`'3,02'` becomes 30,200 cents instead of 302). Every price still parses, so validation passes, but reconcile computes the totals independently from raw and finds the difference:
```bash
sed -i "s/replace(btrim(p), ',', '.')::numeric/replace(btrim(p), ',', '')::numeric/" 00_setup/003_helpers.sql   # the bug
./run.sh setup        # installs the buggy mig.parse_amount_cents()
./run.sh validate     # GATE validate: passed (every price is still "valid")
./run.sh transform    # staging now has wrong prices
./run.sh reconcile    # FAIL order amount total (expected 215226204, actual 12931681164)
                      # FAIL per-order totals, FAIL product price total -> GATE reconcile: 3 check(s) failed
./run.sh load         # refuses: "Phase 04_reconcile has not completed successfully"

sed -i "s/replace(btrim(p), ',', '')::numeric/replace(btrim(p), ',', '.')::numeric/" 00_setup/003_helpers.sql   # the fix
./run.sh setup        # reinstalls the rule; then validate, because it uses the same rule
./run.sh validate && ./run.sh transform && ./run.sh reconcile && ./run.sh load && ./run.sh verify
```

**2. Why was a record rejected?** The report counts findings per rule; the archive has every single record:
```bash
./run.sh report       # part 3: customer | REJECT | email_format | 8, …
./run.sh archive      # archive/<timestamp>/mig_error.csv: one line per finding
grep ",customer,500," archive/*/mig_error.csv
#  …,customer,500,email,user500.example.com,email_format,REJECT,not a valid e-mail address,…
#  …,customer,500,address,unknown,address_format,WARN,"address cannot be parsed, migrated without address",…
grep ",customer_rejected," archive/*/mig_error.csv | grep ",cust_no,500,"
#  ORD-000357, ORD-002357, ORD-004357: rejected because their customer is rejected
```

**3. Run the load twice: nothing changes.** The upserts find every row by its legacy key and write only differences:
```bash
./run.sh load         # after a full run: target counts before and after are identical
                      # (1,884 customers, 298 products, 5,797 orders, 14,432 lines), and the order load
                      # reports "resuming after order ORD-005998", "loaded in 0 batch(es)"
```

**4. Delta sync while the old system keeps running.** **Users** keep changing the old system; the delta brings only those changes over, deletes included:
```bash
./run.sh delta        # 1. source/legacy_changes.sql changes the OLD system, like users still working there:
                      #    customer 150 gets a new e-mail, customer 250's bad e-mail is fixed, new customer 2001
                      #    with order ORD-006001, ORD-000010 is shipped; deleted: ORD-000020, line 4 of ORD-000011,
                      #    and customer 301 with their orders
                      # 2. the delta extract copies only those changes into raw: 3 changed customers + 5 changed
                      #    order lines, 1 deleted customer + 5 deleted order lines
                      # 3. validate .. verify again; production now has the new e-mail, customer 250 with its
                      #    previously rejected orders, the new customer and order, the shipped order;
                      #    4 orders removed (ORD-000020 + customer 301's three), customer 301 deactivated
```

**5. Rollback and start over.** Remove everything the migration loaded, e.g. after a failed verify or between rehearsals:
```bash
./run.sh rollback     # deletes exactly the rows listed in mig.id_map, children first, from ALL runs;
                      # it can't undo: earlier values of rows a delta updated (the whole row is deleted),
                      # deletes and deactivations from 560, or just the last run alone
./run.sh all          # the migration can be repeated (rehearsal!)
./run.sh reset        # or drop the new system completely
```

**6. Cutover: GO.** Freeze the old system, sync the last changes, check everything once more, and decide:
```bash
./run.sh cutover      # freeze old system, final delta (empty if nothing changed since the last delta),
                      # all gates, 4 smoke checks, 4 go/no-go criteria -> (the GO decision)
                      #   if everything is OK: switch the application to the new system manually
                      #   the old system stays frozen as a read-only fallback

./run.sh delta        # fails now: "cannot execute UPDATE in a read-only transaction" (just test: the freeze works)
```

**7. Cutover: NO-GO.** The cutover refuses to start without a successful full run, here after a rollback:
```bash
./run.sh rollback     # production emptied, every run ROLLED_BACK
./run.sh cutover      # PHASE 07_freeze_source FAILED: "No successful full run (or it was rolled back): run ./run.sh all first. Source NOT frozen."
./run.sh report       # run 1 full ROLLED_BACK, run 2 cutover FAILED (07_freeze_source FAILED)
./run.sh unfreeze     # makes frozen old system live again (the NO-GO decision)

./run.sh all          # a new full run, then ./run.sh cutover again
```

**8. After go-live.** Keep the audit trail as files, then remove the working layers:
```bash
./run.sh archive      # only the archive: archive/<timestamp>: report.txt + mig_*.csv files
./run.sh cleanup      # archive, then drop raw, stg, src and the connection to the old system; mig stays
```

> [!NOTE]
> After a full run, a delta and a cutover, the archive holds e.g. 2,656 findings (`mig_error.csv`), 8,081 id map entries and 118 checks.

### Relation to the Flyway scenarios

This demo puts together techniques that the Flyway scenarios show in isolation. No Flyway file is used directly: the techniques are written again in this demo's own scripts.

| Technique | File | Flyway scenario |
|---|---|---|
| Reference data as a desired-state insert | `00_setup/005_target_schema.sql` (`country`, `ON CONFLICT DO NOTHING`) | D1 |
| Quarantine instead of aborting, `pg_input_is_valid` | `mig.parse_date()` in `00_setup/003_helpers.sql`, `02_validate/*`, `mig.error` | D10 |
| Cleanup before constraints: same goal, different technique. D3 uses `NOT VALID` → clean → `VALIDATE` on an existing table; here the data is cleaned in staging and loaded into an already constrained target | `02_validate/*`, `03_transform/*`, the target's constraints | D3 |
| Deduplication with a survivor map | `03_transform/310_stg_customer.sql` | D4 |
| Free text → lookup table | `03_transform/330_stg_product.sql` | D5 |
| Code mapping table | `00_setup/004_code_maps.sql` | D7 |
| Format normalization functions | `00_setup/003_helpers.sql` | D8 |
| Money as integer cents | `mig.parse_amount_cents()` in `00_setup/003_helpers.sql`, all `*_cents` columns | D9 |
| Counts / totals / fingerprints, rollback on mismatch | `04_reconcile/*`, `06_verify/*`, `07_cutover/790_rollback.sql` | D16 |
| Batched load with a checkpoint | `05_load/540_load_order_batched.sql` | D2, D14 |
| Bulk load: `ANALYZE` after loading (partly: dropping indexes before a large load is only a comment) | `03_transform/390_stg_analyze.sql`, `05_load/500_pre_load.sql`, `590_post_load.sql` | D15 |

---

## Rules that make it work

**Source and raw**

1. **The migration never writes the source.** It only reads, from one consistent snapshot. Changes in the old system come from its **users** and **the data owners**, through the old system itself: including the fixes of records found in the quarantine.
2. **Never fix data in `raw`.** Fix a wrong record in the source, a wrong rule in the rules, and what the source can't fix with a documented correction. Raw stays a 1:1 copy of the source.

**Rules and staging**

3. **One rule set for validate and transform.** Both phases use the same parse functions and code maps (`003_helpers.sql`, `004_code_maps.sql`), so they can never disagree about what is valid.
4. **Re-runnable up to the load.** Staging is truncated and rebuilt on every run, and transforms never depend on a previous run. Fixing a rule means changing it and re-running from the first phase that uses it (a transform file: transform onwards; a helper or code map: setup, then validate onwards).
5. **Nothing disappears silently.** Every source row ends up in staging, merged into a survivor, or in `mig.error`. `raw = staged + merged + rejected` is a gate check, and rows deleted in the source are detected and handled by explicit rules, not just left behind.

**Checks and gates**

6. **Gates have thresholds.** Too many rejects means the rules are wrong, not the data.
7. **Checks are computed independently.** Reconcile recomputes totals from raw with its own code, so a bug in a transform rule can't hide itself (walkthrough 1b).

**Load**

8. **Production is written in one phase only (05).** Everything before it can fail without consequences, and the load itself checks that the earlier gates passed.
9. **Every step is atomic or resumable.** Each file runs in one transaction; the only exception, the batched order load, commits per batch with a checkpoint and resumes after a failure.
10. **Loads are idempotent upserts.** Delta runs, reruns after a failure, and resumed batches can't create duplicates.
11. **Keep legacy ids.** `legacy_cust_no` in the target and `mig.id_map` trace every production row back to its source.
12. **Touch only what the migration created.** Deletes and rollback act only on rows listed in `mig.id_map`; rows the application created are never touched.

**Cutover and after**

13. **Rehearse.** Run the whole pipeline on a copy of production several times before the real run, and time it. The timing decides whether you need batching or a delta load.
14. **Cutover strategy:**
    - **big bang:** freeze the source, do a full run, switch;
    - **initial + delta** (as in this demo): do the big load ahead of time, then sync only the changes during a short freeze.
15. **Go-live is a decision with explicit criteria.** Freeze, final delta, all gates, smoke test, then GO / NO-GO. Rollback stays possible only until **users** write to the new system.
16. **Keep the audit trail.** Every run, phase, finding and check is recorded in `mig`, archived as files before cleanup, and kept after it.

> [!NOTE]
> See [Limitations](#limitations) for what this demo doesn't do.

---

## Limitations

### Coverage 

Of its own phase list ([The standard phases](#-the-standard-phases)):

| Phase | Implemented | Coverage |
|---|---|---|
| 0 ASSESS | ✅ `00_assess/`: volumes, missing values, value shapes, duplicates, orphans, inconsistent headers, value lists. <br> Read-only and printed only: results aren't stored or compared between runs | ~90% |
| 1 EXTRACT | ✅ `postgres_fdw` → raw as text, batch id and load time, one consistent snapshot, watermarks | 100% |
| 2 VALIDATE + gate | ✅ structure, integrity, business and dependency checks, quarantine, 5 % threshold | 100% |
| 3 TRANSFORM | ✅ cleanse, normalize, code maps, dedupe, split into staging | 100% |
| 4 RECONCILE + gate | ✅ counts, totals, fingerprints, `raw = staged + merged + rejected` | 100% |
| 5 LOAD | ✅ FK order, idempotent upserts, id map, batched with checkpoint/resume, guard on earlier phases, source deletes, `ANALYZE`. <br> Dropping indexes before a large load is only a comment (→ D15) | ~95% |
| 6 VERIFY + gate | ✅ counts and totals, constraints, business checks, deletes | 100% |
| 7 CUTOVER | ✅ delta sync with deletes, freeze, final delta, smoke test, go/no-go gate, unfreeze, rollback. <br>⚠️ The application switch itself (connection string / DNS) is outside the database and not scripted | ~90% |
| 8 CLEANUP | ✅ archive of the report and all control tables to files, drop raw / stg / src, keep `mig` | 100% |

### Gaps 

Compared with a real migration project:

**Delta and change detection**

1. **Delta processing isn't incremental.** Every run recomputes all of staging instead of only the affected keys (see [Delta run](#-delta-run-runsh-delta)). Fine at this size, but affected keys are mandatory at volume.
2. **Delete and product detection read the whole source** on every delta (key and content comparison). At volume: soft-delete flags, a key-only extract, or CDC.
3. **Updates that don't touch `updated_at`** in customers and order lines aren't seen by the delta.
4. **A deleted survivor whose merged duplicate remains** isn't handled. The duplicate becomes the new survivor with the same e-mail, and the customer load fails on the unique e-mail of the deactivated row.
5. **A record rejected after it was loaded keeps its old version in production.** The loads only upsert what is in staging. If a later delta makes an already migrated record invalid, it is quarantined, but production keeps the last good version without any check failing. 
6. **The product change path is never exercised.** `legacy_changes.sql` changes no product, so every delta reports "0 products changed" (test gap of this demo).

**Rollback, cutover and data protection**

7. **No parallel run or reverse sync after go-live.** Once the new system takes writes, the old one can't simply take over again. Rollback only removes migrated rows, and only before **users** write to the new system.
8. **Rollback doesn't unfreeze the old system.** After a cutover, `./run.sh rollback` removes the migrated rows, but the old system stays read-only until `./run.sh unfreeze`.
9. **The window to the old system isn't technically read-only.** The `postgres_fdw` foreign tables in `src` are writable by default, so "the migration never writes the source" (rule 1) holds by convention only (option `updatable 'false'` in `001_schemas.sql` would enforce it).
10. **Customer deletes deactivate, they don't anonymize.** A GDPR erasure needs the personal columns overwritten as well.

**Scale and operations**

11. **No rehearsal timing.** Rule 13 says to rehearse and time the run, but nothing measures run times at production volume. The phase durations in `mig.run_phase` are the starting point.
12. **No masked or anonymized production copy** for rehearsals. Real rehearsals run on production data, so personal data (names, e-mails, phones) must be masked first.
13. **No performance tuning at volume:** no parallel loads, no index drop/recreate. Both are described (Background, **Load optimization at volume** in [5 LOAD](#-5-load-05_load), D15), not done.
14. **Old and new system on one server.** Both databases run in one container. Real migrations cross servers or networks, where bandwidth, latency, firewalls and extract windows matter.
15. **Same engine on both sides** (PostgreSQL → PostgreSQL). A heterogeneous migration adds type and dialect conversion; the Liquibase part of this project shows those differences.

> [!NOTE]
> The items under **Scale and operations** are better described than demonstrated at demo size.

---

## Extras beyond the phase list and real projects

Things this demo does that the phase list doesn't ask for, and that many real projects don't have:

| Extra | Where | Why it matters |
|---|---|---|
| **Tracking and audit trail** | | |
| Run and phase tracking | `mig.run`, `mig.run_phase`, `mig.phase_start()` / `phase_end()` | Every run and phase is recorded with status and duration; a failed phase can be retried and re-opens its run |
| Report and archive | `run.sh report`, `run.sh archive` | One command shows runs, phase durations, findings per rule and every check; the archive keeps it outside the database |
| Id map | `mig.id_map` | Resolves foreign keys during the load, answers "where did legacy record X go?", and tells rollback and delete handling exactly which rows the migration owns |
| Every extracted version kept | `raw.*` with `_batch_id`, tombstones | Full history of what the source looked like at each extract (every version, with its batch); earlier states can be looked up, although the pipeline itself always works on the latest version |
| **Data quality and rules** | | |
| REJECT vs WARN, propagated rejects | `mig.error.severity`, `240_chk_dependencies.sql` | A bad phone doesn't block a customer; a rejected customer takes its orders with it, instead of failing them later on a FK |
| One rule set for validate and transform | `003_helpers.sql`, `004_code_maps.sql` | Both phases use the same parse functions and code maps, so they can never disagree about what is valid |
| Delta feedback loop | `legacy_changes.sql` change 2 | A record quarantined for dirty data is fixed in the source and picked up by the next delta, together with its children rejected because of it |
| Reproducible numbers | `source/legacy_shop.sql` | Dirty data is planted deterministically, so every expected value in the checks is fixed |
| **Checks** | | |
| Independent checks | `420_rec_totals.sql`, `430_rec_fingerprint.sql` | Totals are recomputed from raw with separate code and compared per order in both directions; md5 fingerprints over sorted values catch swapped or altered values that keep counts and totals intact. A bug in the **transform** can't hide itself |
| Business spot checks | `630_ver_business.sql` | Known outcomes per rule (dedupe, mapping, WARN, reject), the kind of list agreed with **the business** |
| Smoke test with an undone write | `760_smoke_test.sql` | Checks the new system with everyday use cases of the application (login lookup by e-mail, order history, product lookup, placing an order), including the write path, without leaving test data behind |
| **Load and delta** | | |
| Second safety net before production | `500_pre_load.sql`, `mig.require_phase()` | The load refuses to run unless the earlier phases of this run passed, even when started by hand |
| Only real changes written | upserts with `IS DISTINCT FROM` | Delta runs touch only changed rows: less locking, less log, fewer triggers |
| Resumable batched load | `540_load_order_batched.sql`, `mig.checkpoint` | A killed load continues after the last committed batch |
| Delete detection without CDC | `710_delta_sync.sql` (key comparison, tombstones), `560_apply_deletes.sql`, `640_ver_deletes.sql` | Deletes are found although the source only has `updated_at`, and every entity has an explicit rule for what a delete means in production |
| **Cutover and operations** | | |
| Automated go/no-go gate | `780_go_no_go.sql` | The go-live decision is checked by code (old system frozen, nothing changed after the final delta, every phase and check passed), not only agreed in a meeting |
| Safe freeze | `720_freeze_source.sql`, `729_unfreeze_source.sql` | The freeze refuses to start without a successful full run, and a NO-GO undoes it with one command |
| Two equivalent runners | `run.sh`, `run.ps1` | The same commands on Linux, macOS and Windows |

# Migration-Flyway-Liquibase-Demo

A hands-on catalog of **database migration scenarios**.\
Every scenario is a small, self-contained, runnable example made of plain migration scripts (`.sql`, `.yaml`, `.xml`), executed through Docker.\
No application code, no build tool.

<!-- contents -->
**Contents**

- [Purpose](#purpose)
  - [Principles](#principles)
- [Database versioning (the migration-based approach)](#database-versioning-the-migration-based-approach)
  - [What it solves](#what-it-solves)
  - [What belongs in these migrations](#what-belongs-in-these-migrations)
  - [What belongs in custom-SQL data migrations](#what-belongs-in-custom-sql-data-migrations)
- [Background: considerations for versioned migrations](#background-considerations-for-versioned-migrations)
  - [Adopting versioning on an existing database](#adopting-versioning-on-an-existing-database)
  - [Versioning database code (procedures, functions, views, types)](#versioning-database-code-procedures-functions-views-types)
  - [Backward-compatible changes](#backward-compatible-changes)
  - [Guarded scripts vs versioned migrations](#guarded-scripts-vs-versioned-migrations)
  - [Testing and reviewing migrations](#testing-and-reviewing-migrations)
- [Complex data migrations: key notes](#complex-data-migrations-key-notes)
  - [Stages, phases and gates](#stages-phases-and-gates)
- [Project layout](#project-layout)
- [Running](#running)
- [Troubleshooting](#troubleshooting)
- [Further reading](#further-reading)
<!-- /contents -->

## Purpose

Most migration tutorials stop at `CREATE TABLE` and `ADD COLUMN`.\
Real migrations fail on other things: locks on large tables, dirty data that breaks a new constraint, duplicates that block a unique index, renames that break the running application, or SQL that works on one engine and fails on another.

This project covers those cases in three parts. Each part has its own README with the scenario list and how to run it:

| Part | Tool | Database | Focus |
|---|---|---|---|
| [`/flyway`](flyway/README.md) | Flyway 11 (OSS) | PostgreSQL 17 | **Schema evolution and data migration patterns** (38 scenarios): additive changes, zero-downtime expand/contract refactoring, team operations (branch version conflicts, edited migrations) and data migrations, including the classic reasons migrations fail in production |
| [`/liquibase`](liquibase/README.md) | Liquibase 4.33 (OSS) | PostgreSQL 17, MySQL 8.4, SQL Server 2022 | **Cross-engine syntax conflicts** (23 scenarios): data types, auto-generation, defaults, identifiers and dialect differences, and how one changelog handles all three engines; plus rollback, contexts and labels |
| [`/full-custom-migration`](full-custom-migration/README.md) | plain SQL + `psql` | PostgreSQL 17 | **A complete migration process as one complex demo**: a legacy e-shop migrated into a new model through raw → staging → production, with validation, quarantine, reconciliation, gates, delta sync, rollback and an audit trail |

**How the parts relate**
- **Flyway and Liquibase are fine-grained samples.** Each scenario isolates one technique or one conflict, mainly to demonstrate what these two Java migration tools can do: versioned and repeatable migrations, non-transactional scripts, repair, changesets, preconditions, `dbms` variants, properties, quoting strategies, and so on.
  - In short: they are primarily for **schema changes (DDL)** and the small data changes that belong to them, like reference data (currencies, statuses, countries) and backfills.
- The two tool parts deliberately don't overlap. Flyway covers *what* to migrate and *how to do it safely*. Liquibase covers *how to write it once for multiple engines*.
- **The full custom migration is the big picture**: how a full data migration is organized as a process, from the old system to production. It deliberately uses no migration tool, because a one-time data migration needs phases, gates and repeated rehearsals, which is a different job than versioning a schema. It reuses many techniques from the Flyway scenarios (D1, D2, D3, D4, D5, D7, D8, D9, D10, D14, D15, D16). Its [README](full-custom-migration/README.md) also contains the **theoretical background**: types of migrations, ETL vs ELT, full/incremental/CDC, offline vs online, and the standard phases.
  - In short: it is for **moving large volumes of business data (DML)**, like customers and orders, from one system to another, once.

> [!IMPORTANT]
> **Flyway and Liquibase are not built for complex data migrations.** They version and apply scripts; they don't validate, transform, reconcile or quarantine data. Everything that makes a complex migration work (parsing rules, deduplication, mappings, quarantine, reconciliation, gates, id mapping, delta sync) is **custom SQL** that you write yourself. The tools can at most *run* that SQL in order. Flyway's "run each script once" model is not appropriate for re-runnable phases. Liquibase fits better (`runAlways`, labels, `HALT` preconditions as gates), but the logic still stays custom SQL. Complex migrations are therefore primarily custom-SQL based, orchestrated by a script, a CI pipeline or a scheduler, or built with dedicated tools (dbt, AWS/Azure DMS, Informatica, Talend, SSIS). Use Flyway or Liquibase for what they're good at: the target **schema**, **versioning** and smaller data changes that ship with application releases.

### Principles

- **One scenario = one folder = one isolated schema (Flyway) / database (Liquibase).** Each scenario brings its own small starting model, so any scenario can be run and reset on its own.
- **Plain scripts only.** Everything that runs is a file you can read.
- **Every scenario is verifiable**, with assertions or inspect queries (details in each part's README).
- **Every claim was run.** Each scenario README describes the observed behavior, including the surprises.

> [!WARNING]
> Exception: the scenarios added later (Flyway B11, B12, C1, C2 and Liquibase L21–L23) haven't been run yet; their READMEs say so.

---

## Database versioning (the migration-based approach)

### What it solves

**Problem:** the same database exists in several environments (local, dev, test, production), and each one can be on a different version of the schema. Without a tool, nobody knows reliably which scripts have run where, so a script gets skipped or runs twice.

**Solution:** every schema change is a numbered script in the repository, and the tool keeps a record *inside the database* of what has been executed.

```
db/migration/
  V1__create_customers.sql
  V2__create_orders.sql
  V3__add_email_to_customers.sql
  V4__index_orders_date.sql
```

On every run (for example when a Spring Boot application starts), Flyway:
1. reads the `flyway_schema_history` table in the database (e.g. "executed up to V3"),
2. runs only the new scripts, in order (V4),
3. records V4 with its checksum in the history.

| Version | Description | Checksum | Executed |
|---|---|---|---|
| 1 | create customers | 1823… | 2026-01-10 |
| 2 | create orders | -9921… | 2026-01-10 |
| 3 | add email to customers | 4410… | 2026-03-02 |

**Result:** any database, from empty to production, reaches the same version by the same path. That's reproducible and automated, so it fits into CI/CD.

> [!IMPORTANT]
> **Rule:** an executed script is never changed. If it changes, the checksum no longer matches and Flyway refuses to run. Corrections are made with a new script.

Liquibase works the same way: its history table is `DATABASECHANGELOG`, and a changeset (identified by `id` + `author` + file) takes the place of a numbered script.

### What belongs in these migrations

Flyway and Liquibase are primarily tools for **database versioning and DDL** (Data Definition Language): `CREATE`, `ALTER` and `DROP` of tables, columns, indexes, constraints, views and functions.

Of **DML** (Data Manipulation Language), **only reference / lookup data belongs there, as predefined data**: currencies, statuses, document types, countries. That data is small, stable, and part of the model itself, because the application doesn't work without it (see Flyway **[D1](flyway/scenarios/D1-seed-reference-data)**).

The Flyway data scenarios (D2–D16) show what *can* be done with Flyway, mainly as techniques. At real-world volume and complexity, that work moves into a separate, custom-SQL process like [`/full-custom-migration`](full-custom-migration).

### What belongs in custom-SQL data migrations

Custom-SQL data migrations are primarily focused on **business data**: customers, orders, invoices, with bulk imports and one-time data migrations between systems (see [`/full-custom-migration`](full-custom-migration)).

The custom-SQL migration deliberately does **not** do database versioning. It leaves versioning to Flyway or Liquibase and tracks something else: **its runs**, not the schema's history.

1. **The target schema belongs to Flyway or Liquibase.** In the demo, [`00_setup/005_target_schema.sql`](full-custom-migration/00_setup/005_target_schema.sql) creates it so the demo is self-contained. In a real project:
   1. Flyway or Liquibase creates or changes the target schema (versioned, as in any release).
   2. The custom-SQL pipeline loads the data into that schema.
   3. A later Flyway or Liquibase migration tightens or cleans up the schema (the expand/contract pattern).

---

## Background: considerations for versioned migrations

What to keep in mind when a database is versioned with migrations, beyond the basics above.

### Adopting versioning on an existing database

Most projects don't start with an empty database: the schema already exists, unversioned, on several environments.
1. **Generate a baseline script** from the production schema: SSMS "Script Table As" / "Generate Scripts", `pg_dump --schema-only`, or Liquibase `generate-changelog`.
2. **Check that every environment really has that schema** (see drift below), and fix the differences first. Otherwise the baseline describes a database that only exists on one of them.
3. **Mark the baseline as already applied** on the existing databases: Flyway `baseline` (or `baselineOnMigrate=true` with `baselineVersion`), Liquibase `changelog-sync`. New, empty databases run the baseline script normally.
4. **From then on, every change is a new migration.**

### Versioning database code (procedures, functions, views, types)

Tables are straightforward to version with numbered scripts. Database *code* is harder, and in SQL-centric systems (business logic in stored procedures) it is most of the database.

- **Repeatable scripts for code.** Keep each object's full definition in one file with `CREATE OR REPLACE` / `CREATE OR ALTER`. Flyway `R__` scripts re-run whenever their checksum changes; the Liquibase equivalent is `runOnChange: true`. Diffs stay readable, and git holds the history of every procedure.
- **Dependency order.** Code depends on tables, types, views and other code. Versioned scripts create the structure first, and repeatable scripts run after them. Flyway runs repeatable scripts in order of their description, so name them to control that order (`R__01_types.sql`, `R__02_functions.sql`, ...).
- **Types used by code can't change in place.** Example: a SQL Server table type (TVP) used by procedures. The change needs one ordered migration: drop the dependent procedures, drop and recreate the type, recreate the procedures.
- **Drift.** Someone applies a hotfix directly on production (`ALTER PROCEDURE ...`). The repository and the database now differ, and the next deployment either overwrites the hotfix or fails.
  - Flyway `validate` checks the migration scripts against the history table. It does **not** notice manual changes made in the database.
  - Detecting drift needs a schema comparison against a database built from the repository (Liquibase `diff`, or a schema-compare tool).
  - The rule that prevents drift: every change, even an emergency fix, goes through a migration script.
- **New code, new execution plan.** A changed procedure is compiled again and can get a very different plan (parameter sniffing). See the post-migration checks in the [background of the full custom migration](full-custom-migration/README.md#background-migration-considerations).

### Backward-compatible changes

Expand/contract ([Flyway section B](flyway/README.md#b-breaking-changes-with-expandcontract-zero-downtime)) applies to database code and its callers too:
- **New parameter with a default value.** Existing calls keep working (T-SQL: `@Status varchar(20) = 'Open'`).
  - In PostgreSQL, `CREATE OR REPLACE FUNCTION` can't change the argument list: a different list creates a second function (an overload). Drop the old version in the contract step.
- **Explicit column lists, never `*`.** An `INSERT` without a column list breaks as soon as a column is added, and `SELECT *` changes the shape of the result. With explicit lists, an expand step can't break existing code.
- **Removing or changing a parameter is a contract step.** Do it only after every caller has moved to the new signature.

### Guarded scripts vs versioned migrations

There are two ways to make a script safe to run repeatedly:

- **Guarded (idempotent) scripts** check the current state on every run:
  - T-SQL: `IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = 'x' AND type = 'U') CREATE TABLE ...`
  - PostgreSQL: `CREATE TABLE IF NOT EXISTS ...`

  They can run anywhere at any time, but they only know *whether* an object exists, not *which version* of it. A column changed later isn't detected, and the order of changes has to be managed by hand.
- **Versioned migrations** rely on the history table. Every script runs exactly once, in order, and the database knows exactly which version it's on.

The two combine well: versioned migrations for changes, and the guarded style for anything that must stay re-runnable (`R__` scripts, and the `00_setup` of the full custom migration).

### Testing and reviewing migrations

- **Run every migration in CI** against a fresh database container, from empty to the latest version. Before a release, also run it against a **production-like copy**: most of the failures shown in the Flyway scenarios (locks, dirty data, duplicates) only appear with real data and volumes.
- **Time the run on the copy.** The timing decides whether a migration needs batching, a delta load or a maintenance window.
- **Keep scripts small and single-purpose**, so a review can actually check them. A changed `JOIN` in a 2,000-line procedure can change the execution plan and performance, and that isn't visible in a diff. That is one more reason for the [post-migration checks](full-custom-migration/README.md#performance-after-the-migration).

---

## Complex data migrations: key notes

The most important points of the [full custom migration](full-custom-migration/README.md). It migrates a denormalized legacy e-shop (2,000 customers, 300 products, 6,000 orders, full of planted dirty data) into a new normalized model. Details, scripts and walkthroughs are in its README.

### Stages, phases and gates

A **stage** is a place where the data rests between two steps, in one defined state.\
A **phase** is a step of work; a stage is where its result is kept.\
A **gate** is a check that stops the run if it fails; the next phase starts only after the previous gate passes.

| Stage | Also called | In the demo |
|---|---|---|
| Source | legacy data | database `legacy_shop`, read through `postgres_fdw` (schema `src`) |
| Raw | landing data, bronze layer | schema `raw`: exact copy, all columns as `text` |
| Staging | cleansed, transformed, mapped data, silver layer | schema `stg`: typed, cleaned, still keyed by the legacy keys |
| Target | production, gold layer | schema `public` in database `shop` |
| *Control (not a data stage)* | control / audit data | schema `mig`: runs, phases, quarantine, mappings, id map, checks; kept as the audit trail |

```
 0 ASSESS      profile the source: volumes, formats, dirty data, orphans, duplicates
 1 EXTRACT     copy source 1:1 into  raw.*            (no changes, add batch id + load time)
 2 VALIDATE    check raw against rules  -> report(error) + quarantine(rejected)  [GATE 1]
 3 TRANSFORM   raw.* -> stg.*   cleanse, normalize, map codes, dedupe, split/merge, stg stats
 4 RECONCILE   stg vs raw: counts, totals, sums, fingerprints, orphans   [GATE 2]
 5 LOAD        stg.* -> target  (in FK order, batched, id mapping)
 6 VERIFY      target vs stg/raw, totals, constraints, business checks, deletes  [GATE 3]
 7 CUTOVER     freeze old system, sync delta, switch the app, keep a rollback path
 8 CLEANUP     drop raw/stg after a retention period, archive the reports
```

**How a gate stops the run:** the gate function raises an exception, `psql` (with `ON_ERROR_STOP=1`) exits with an error, and the orchestrator marks the phase `FAILED` and stops. As a second safety net, the load itself refuses to start unless validate, transform and reconcile are `DONE` in this run.

The demo implements all nine phases, including delete detection in the delta and a scripted cutover (freeze, final delta, smoke test, go/no-go gate). What it doesn't do, and what it does beyond the phase list: [Limitations](full-custom-migration/README.md#limitations) and [Extras](full-custom-migration/README.md#extras-beyond-the-phase-list).

## Project layout

```
Migration-Flyway-Liquibase-Demo/
├── README.md                              # this file: purpose, common theory, key notes
├── flyway/
│   ├── README.md                          # scenarios A1–A8, B1–B12, C1–C2, D1–D16, layout, running
│   ├── docker-compose.yml                 # postgres:17 (port 5433) + flyway/flyway:11
│   ├── run.sh | run.ps1
│   └── scenarios/<ID>-<name>/             # one folder per scenario (38)
│       ├── README.md                      # goal, key points, how to run
│       ├── migrations/                    # V1 = starting model, V2+ = the change shown
│       ├── verify.sql                     # assertions: ./run.sh <ID> verify
│       ├── app_v1.sql, app_v2.sql         # optional: queries of the old / new application version
│       └── demo_*.sql                     # optional: extra demos: ./run.sh <ID> sql <file>
├── liquibase/
│   ├── README.md                          # scenarios L1–L23, layout, running
│   ├── docker-compose.yml                 # postgres (5434), mysql (3307), mssql (1434) + liquibase image
│   ├── run.sh | run.ps1
│   ├── common/inspect-<engine>.sql        # all columns of all tables, with the real type each engine created (run after every scenario)
│   └── scenarios/<ID>-<name>/             # one folder per scenario (23)
│       ├── README.md                      # goal, key points, how to run
│       ├── changelog.yaml, changelog.xml  # the same changesets in both formats
│       ├── inspect/<engine>.sql           # what to check after the update (postgres, mysql, mssql)
│       └── *.csv, *.png, failure-demo.*   # optional: data for loadData, binary data, a failing changelog
└── full-custom-migration/
    ├── README.md                          # theoretical background + the process, step by step
    ├── docker-compose.yml                 # postgres (5435): databases legacy_shop (old) + shop (new)
    ├── run.sh | run.ps1
    ├── source/                            # the old system with intentionally dirty data + changes for the delta run
    ├── 00_assess/  00_setup/  01_extract/  02_validate/  03_transform/
    ├── 04_reconcile/  05_load/  06_verify/  07_cutover/  08_cleanup/
    └── archive/                           # created by ./run.sh archive / cleanup: report + control tables as files
```

Isolation:
- **Flyway:** each scenario runs in its own PostgreSQL schema (`b1`, `d4`, ...).
- **Liquibase:** each scenario gets its own database per engine (`l1`, `l2`, ...), dropped and re-created on every run by default.
- **Full custom migration:** its own PostgreSQL container. The old system (`legacy_shop`) and the new one (`shop`) are separate databases, connected with `postgres_fdw`.

---

## Running

Requirements: Docker with Compose. On Windows, use `run.ps1` (PowerShell) or `run.sh` (Git Bash). Both take the same arguments. Images are pulled on the first run.

> [!NOTE]
> SQL Server needs about 2 GB RAM. If its container exits or never becomes healthy, raise Docker Desktop's memory limit.

```bash
cd flyway                && ./run.sh B1 all     # clean + migrate + verify one scenario
cd liquibase             && ./run.sh L1         # all engines, YAML: reset DB -> update -> inspect
cd full-custom-migration && ./run.sh all        # old system + setup + extract .. verify
```

All commands and options are in each part's README: [Flyway](flyway/README.md#running), [Liquibase](liquibase/README.md#running), [full custom migration](full-custom-migration/README.md#running-the-demo).

**Connecting with a GUI client:**
- PostgreSQL (Flyway): `localhost:5433`, demo/demo, database `demo`
- PostgreSQL (Liquibase): `localhost:5434`, demo/Demo_Pass123
- MySQL: `localhost:3307`, root/Demo_Pass123
- SQL Server: `localhost:1434`, sa/Demo_Pass123
- PostgreSQL (full custom migration): `localhost:5435`, demo/demo, databases `legacy_shop` and `shop`

> [!NOTE]
> **Stop everything:** `docker compose down -v` in `flyway/`, `liquibase/` and `full-custom-migration/`.
> `-v` deletes the demo databases too; the next run recreates them from the scripts.

---

## Troubleshooting

Many failures in this repo are deliberate: they are what a scenario demonstrates. Check the scenario's README first. The tables below cover failures of the setup and the runners, and the ones you are likely to hit while changing a scenario.

**All parts**

| Symptom | Fix |
|---|---|
| `docker compose` / `docker: command not found`, or `Cannot connect to the Docker daemon` | Start Docker Desktop and wait until the engine is running. |
| `port is already allocated` (5433, 5434, 3307, 1434, 5435) | Another container or a local database holds the port. Stop it, or change the host side of `ports:` in that part's `docker-compose.yml` (and the GUI connection). |
| Git Bash: paths like `/scenarios/...` turn into `C:/Program Files/Git/scenarios/...` | Use the `run.sh` scripts, which set `MSYS_NO_PATHCONV=1`. When you call `docker compose` by hand from Git Bash, prefix it with `MSYS_NO_PATHCONV=1`. |
| PowerShell refuses to run `run.ps1` (execution policy) | `powershell -ExecutionPolicy Bypass -File .\run.ps1 ...`, or `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once. |
| A scenario behaves unlike its README after experiments | Reset it: `./run.sh <ID> clean` (Flyway), a plain `./run.sh <ID>` (Liquibase drops and re-creates the database), or `docker compose down -v` for a completely fresh container. |

**Flyway**

| Symptom | Fix |
|---|---|
| `Validate failed: ... checksum mismatch for migration version N` | An applied migration was edited. Revert the edit and put the change in a new `V<n+1>__...sql`. `repair` is only right for cosmetic edits: see [C2](flyway/scenarios/C2-checksum-mismatch). |
| `Detected failed migration to version N` | A non-transactional migration failed halfway and is recorded as failed. Fix the cause, run `./run.sh <ID> repair`, then `migrate` again ([D2](flyway/scenarios/D2-batched-backfill), [D14](flyway/scenarios/D14-resumable-migration)). |
| `Detected resolved migration not applied to database` | A lower version arrived after a higher one was applied (typically a merged branch). Renumber it, or run with `FLYWAY_ARGS=-outOfOrder=true`: see [C1](flyway/scenarios/C1-branch-version-conflict). |
| `CREATE INDEX CONCURRENTLY cannot run inside a transaction block` | The migration needs a `.conf` file next to it with `executeInTransaction=false` ([A4](flyway/scenarios/A4-index-concurrently)). |
| `CREATE INDEX CONCURRENTLY` hangs forever | Flyway's own lock holds a transaction open, and `CONCURRENTLY` waits for it. Keep `FLYWAY_POSTGRESQL_TRANSACTIONAL_LOCK=false` in `flyway/docker-compose.yml`. |
| A migration waits on a lock, or fails with `canceling statement due to lock timeout` | Another session holds a lock on the table. `./run.sh A8 sql demo_show_blocking.sql` shows who blocks whom. The timeout is the intended guard ([A8](flyway/scenarios/A8-lock-timeout-guard)): retry when the blocker is gone. |

**Liquibase**

| Symptom | Fix |
|---|---|
| SQL Server container exits or never becomes healthy | It needs about 2 GB of RAM: raise Docker Desktop's memory limit. The first start also takes noticeably longer than PostgreSQL or MySQL. |
| MySQL runs fail with a missing JDBC driver | The official Liquibase image doesn't include it. Rebuild the derived image: `docker compose build` in `liquibase/` (it runs `lpm add mysql`). |
| `UPDATE SUMMARY` shows changesets as `Filtered out: DBMS mismatch` | Expected: that changeset is the variant for another engine (`dbms:`). |
| `rerun` fails with a checksum validation error after editing a changeset | `rerun` keeps the database, so only `runOnChange` changesets may change. Run without `rerun` to reset the database, or add a new changeset. |
| A YAML changelog fails to parse at a type like `decimal(12,2)` | Inside a YAML flow map (`{ ... }`) the comma ends the value. Quote it: `type: "decimal(12,2)"`. |
| SQL Server `Msg 1934 ... incorrect settings: 'QUOTED_IDENTIFIER'` when writing by hand | Tables with filtered indexes or persisted computed columns need `SET QUOTED_IDENTIFIER ON`. `sqlcmd` has it off unless started with `-I` ([L16](liquibase/scenarios/L16-partial-index), [L18](liquibase/scenarios/L18-computed-columns)). |
| `Rollback` fails with `RollbackImpossibleException` / "No inverse to ... RawSQLChange" | Raw SQL changesets have no automatic rollback. Add an explicit `rollback:` block ([L22](liquibase/scenarios/L22-rollback-and-contexts)). |
| Test data appears in a "production" run | Without `--context-filter`, every changeset runs, including those with a context. Pass `LB_ARGS=--context-filter=prod` ([L22](liquibase/scenarios/L22-rollback-and-contexts)). |

**Full custom migration**

| Symptom | Fix |
|---|---|
| `GATE ...: n check(s) failed` | The gate is doing its job. `./run.sh report` lists every failed check with the expected and actual value. Fix the rule, mapping or data, then re-run from that phase on. |
| `./run.sh load` refuses: "Phase ... has not completed successfully" | The load only starts when validate, transform and reconcile are `DONE` in the current run. Run them first (`./run.sh all` runs everything up to verify). |
| A mapping or rule was edited directly in the database and the run is now off | `./run.sh setup` restores the code maps and helper functions; it is idempotent. |
| `./run.sh delta` fails with a read-only error after a cutover | The cutover froze the old system. `./run.sh unfreeze` makes it writable again (the NO-GO path). *Not yet run.* |
| Want to repeat the migration | `./run.sh rollback` deletes exactly the migrated rows (via `mig.id_map`), then `./run.sh all`. `./run.sh reset` drops the whole new database instead; the old system stays. |

---

## Further reading

- Flyway: [Documentation](https://documentation.red-gate.com/flyway) · [Source and issues](https://github.com/flyway/flyway)
- Liquibase: [Documentation](https://docs.liquibase.com/) · [Changelogs](https://docs.liquibase.com/concepts/changelogs/home.html) · [Preconditions](https://docs.liquibase.com/concepts/changelogs/preconditions.html) · [Contexts](https://docs.liquibase.com/concepts/changelogs/attributes/contexts.html) · [Labels](https://docs.liquibase.com/concepts/changelogs/attributes/labels.html)
- PostgreSQL: [Explicit locking](https://www.postgresql.org/docs/current/explicit-locking.html) · [`CREATE INDEX` (incl. `CONCURRENTLY`)](https://www.postgresql.org/docs/current/sql-createindex.html) · [`ALTER TABLE`](https://www.postgresql.org/docs/current/sql-altertable.html) · [Table partitioning](https://www.postgresql.org/docs/current/ddl-partitioning.html) · [`postgres_fdw`](https://www.postgresql.org/docs/current/postgres-fdw.html)
- MySQL: [Online DDL](https://dev.mysql.com/doc/refman/8.4/en/innodb-online-ddl.html) · [Statements that cause an implicit commit](https://dev.mysql.com/doc/refman/8.4/en/implicit-commit.html) · [Data types](https://dev.mysql.com/doc/refman/8.4/en/data-types.html)
- SQL Server: [Data types](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-types-transact-sql) · [Filtered indexes](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/create-filtered-indexes) · [`SET QUOTED_IDENTIFIER`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-quoted-identifier-transact-sql)
- Patterns: [Parallel change (expand/contract)](https://martinfowler.com/bliki/ParallelChange.html) · [Evolutionary database design](https://martinfowler.com/articles/evodb.html) · [Database refactoring catalog](https://databaserefactoring.com/)
- Data migration tooling: [dbt](https://docs.getdbt.com/) · [AWS Database Migration Service](https://docs.aws.amazon.com/dms/latest/userguide/Welcome.html) · [Medallion architecture (bronze/silver/gold)](https://www.databricks.com/glossary/medallion-architecture)

# Flyway on PostgreSQL — schema evolution and data migration patterns

Most migration tutorials stop at `CREATE TABLE` and `ADD COLUMN`.<br>
Real migrations fail on other things: locks on large tables, dirty data that breaks a new constraint, duplicates that block a unique index, renames that break the running application, or SQL that works on one engine and fails on another.

**Schema evolution and data migration patterns** (38 scenarios) for **Flyway 11 (OSS)** on **PostgreSQL 17**:

- Additive (non-breaking) changes
- Zero-downtime expand/contract refactoring (breaking changes)
- Team operations (version conflicts between branches, edited migrations)
- Data migrations

They target the classic reasons migrations fail in production: locks on large tables, dirty data that breaks a new constraint, duplicates that block a unique index, and renames that break the running application.

Each scenario isolates one technique, mainly to demonstrate what Flyway can do: versioned and repeatable (`R__`) migrations, non-transactional scripts, `repair`, `baseline`, and so on.

In short: Flyway is primarily for **schema changes (DDL)** and the small data changes that belong to them, like reference data (currencies, statuses, countries) and backfills.

For the common theory (database versioning, what belongs in migrations, considerations), see the [main README](../README.md).

<!-- contents -->
**Contents**

- [Principles](#principles)
- [Running](#running)
- [Layout](#layout)
- [Scenarios](#scenarios)
  - [Top 5 most complex scenarios](#top-5-most-complex-scenarios)
  - [A. Additive (non-breaking) changes](#a-additive-non-breaking-changes)
  - [B. Breaking changes with expand/contract (zero downtime)](#b-breaking-changes-with-expandcontract-zero-downtime)
  - [C. Team operations](#c-team-operations)
  - [D. Data migrations](#d-data-migrations)
- [Limitations and Gaps](#limitations-and-gaps)
<!-- /contents -->

## Principles

- **One scenario = one folder = one PostgreSQL schema** (`b1`, `d4`, ...). Each scenario brings its own small starting model (`V1__setup.sql`), so any scenario can be run and reset on its own.
- **Every scenario is verifiable.** `verify.sql` contains assertions: `NOTICE: OK ...`, or an exception.
- **Expand/contract scenarios simulate the application.** `app_v1.sql` / `app_v2.sql` contain the queries the old and the new app version run, showing both keep working between phases.
- **Every claim was run.** Each scenario README describes the observed behavior, including the surprises. Exception: **B11, B12, C1 and C2** were added later and haven't been run yet; their READMEs say so and describe the expected behavior.

## Running

Requirements: Docker with Compose. On Windows, use `run.ps1` (PowerShell) or `run.sh` (Git Bash). Both take the same arguments.

```bash
./run.sh B1 all                 # clean + migrate + verify
./run.sh B1 clean
./run.sh B1 migrate 2           # only up to V2 (for expand/contract step-by-step)
./run.sh B1 sql app_v1.sql      # run an app or demo script against the scenario schema
./run.sh B1 info | validate | repair
./run.sh B1 psql                # interactive session (search_path = b1)

LOCATIONS=migrations,late ./run.sh C1 migrate            # other / several migration folders of the scenario
FLYWAY_ARGS=-outOfOrder=true ./run.sh C1 migrate         # extra Flyway options
```
PowerShell: `$env:LOCATIONS = "migrations,late"; $env:FLYWAY_ARGS = "-outOfOrder=true"; .\run.ps1 C1 migrate` (clear them with `Remove-Item Env:LOCATIONS, Env:FLYWAY_ARGS`).

**GUI client:** PostgreSQL `localhost:5433`, demo/demo, database `demo`.

**Stop everything:** `docker compose down -v`.

> [!NOTE]
> How a scenario actually runs (`./run.sh <ID> [action] [arg]`):
>
> 0. **Everything runs in Docker.** PostgreSQL runs as a container, and Flyway runs as a short-lived container for each command (`docker compose run --rm`). 
> <br>The `./scenarios` folder is mounted into both, read-only.
> <br> **Main source**: `./scenarios/<ID>/migrations/Vx__..sql`
> 1. **`flyway clean`** (optional; only `all` and `clean` actions): runs in the Flyway container, and drops everything in provided schema (`-schemas=<id>`), including its `flyway_schema_history`.
> 2. **`flyway migrate`**: runs in the Flyway container, executing the migration scripts from provided folders (`-locations`, default only `migrations/`) in the order of the naming convention: `V1__`, `V1_1_`, `V2__`, … 
> <br> Only versions not yet in `flyway_schema_history` run, each in its own transaction and recorded there. `migrate <version>` stops at that version (`-target`).
> 3. **`verify`**: runs the scenario's own `verify.sql` with psql (PostgreSQL container), with `search_path` set to the scenario's schema. It prints `NOTICE: OK ...` or fails with an exception.
> 4. **`sql <file>`**: runs one of the scenario's additional app or demo scripts against the scenario schema with psql (PostgreSQL container). It is not recorded in `flyway_schema_history`.

## Layout

```
flyway/
├── docker-compose.yml                 # postgres:17 (port 5433) + flyway/flyway:11
├── run.sh | run.ps1                   # ./run.sh <ID> [migrate [v]|info|validate|repair|clean|verify|sql <file>|psql|all]
└── scenarios/
    ├── A4-index-concurrently/
    │   ├── README.md                  # goal, versions, key points, how to run
    │   ├── migrations/
    │   │   ├── V1__setup.sql          # the scenario's own starting model + data
    │   │   ├── V2__create_index_concurrently.sql
    │   │   └── V2__create_index_concurrently.sql.conf   # executeInTransaction=false
    │   ├── demo_invalid_index.sql     # optional demos (failures, timings, ...)
    │   └── verify.sql                 # assertions
    ├── B1-rename-column/
    │   ├── migrations/V1..V4          # setup, expand, migrate, contract
    │   ├── app_v1.sql                 # old app queries (work until contract)
    │   ├── app_v2.sql                 # new app queries (work from migrate on)
    │   └── ...
    ├── C1-branch-version-conflict/
    │   ├── migrations/                # main after a correct merge
    │   ├── branch-b/  late/           # extra folders, combined via LOCATIONS
    │   └── ...
    └── ...
```

Each scenario runs with `-schemas=<id>` and `-locations=filesystem:/scenarios/<folder>/migrations` (or the folders listed in `LOCATIONS`).

## Scenarios

### Top 5 most complex scenarios

Ranked by how many steps they take and how much can go wrong in production:

| # | Scenario | Why it's complex |
|---|---|---|
| 1 | [B9](scenarios/B9-pk-int-to-bigint): widen a PK `int` → `bigint` with referencing FKs | The longest scenario. It needs shadow columns on the table and on every referencing table, a batched backfill, concurrent unique indexes, and a swap of PK and FKs using only catalog changes in one short transaction |
| 2 | [B11](scenarios/B11-partition-existing-table): partition an existing large table *(not yet run)* | Turns the old table into the first partition without copying data. It needs a validated `CHECK` so `ATTACH` skips the scan, a PK swap to include the partition key, and the sequence moved to the new table |
| 3 | [D4](scenarios/D4-deduplication): deduplication before a UNIQUE constraint | A survivor map, child rows moved to the survivor even where children have their own unique keys, then deleting the duplicates. Data changes that can't be undone |
| 4 | [B6](scenarios/B6-split-table): split a table (`customer.address_*` → `address`) | Two tables kept in sync both ways while old and new app versions run, without endless trigger loops (`pg_trigger_depth`) |
| 5 | [D14](scenarios/D14-resumable-migration): resumable migration | A procedure that commits per batch with a checkpoint table. A killed run continues where it stopped, and a half-failed non-transactional migration is cleaned up with `flyway repair` |

Next in line: [B8](scenarios/B8-merge-tables) (merge two tables behind a view with `INSTEAD OF` triggers) and [B12](scenarios/B12-enum-to-lookup-table) (enum → lookup table).

### A. Additive (non-breaking) changes

| ID | Scenario | Key point |
|---|---|---|
| [A1](scenarios/A1-add-table-with-fk) | Add a table + FK to an existing table | FK columns need their own index |
| [A2](scenarios/A2-add-nullable-column) | Add a nullable column | Catalog-only, proven with `pg_relation_filenode` |
| [A3](scenarios/A3-add-column-with-default) | Add a column with a default | Constant default: instant (PG11+). Volatile default (`gen_random_uuid()`, `random()`): full table rewrite |
| [A4](scenarios/A4-index-concurrently) | Create an index `CONCURRENTLY` | Non-transactional migration. Recovering from a failed build that leaves an `INVALID` index |
| [A5](scenarios/A5-unique-constraint-online) | Add a unique constraint online | `CREATE UNIQUE INDEX CONCURRENTLY`, then `ADD CONSTRAINT ... USING INDEX` |
| [A6](scenarios/A6-fk-check-not-valid) | Add a FK / CHECK as `NOT VALID`, then `VALIDATE` | Two migrations, short locks |
| [A7](scenarios/A7-enum-add-value) | Add an enum value | Can't be used in the transaction that added it |
| [A8](scenarios/A8-lock-timeout-guard) | `lock_timeout` guard | Fail fast instead of queueing behind a long query and blocking all traffic |

### B. Breaking changes with expand/contract (zero downtime)

Each scenario is a sequence of versions: **expand → migrate data → (app switches) → contract**.

| ID | Scenario | Technique |
|---|---|---|
| [B1](scenarios/B1-rename-column) | Rename a column | New column + bidirectional sync trigger, backfill, drop old |
| [B2](scenarios/B2-rename-table) | Rename a table | Rename + auto-updatable compatibility view in one transaction |
| [B3](scenarios/B3-change-column-type) | Change a column type (`float` money → `numeric`) | Which type changes are free, shadow column for the rest |
| [B4](scenarios/B4-not-null-safely) | Make a column NOT NULL | `CHECK NOT VALID` **first**, backfill, `VALIDATE`, `SET NOT NULL` without a scan |
| [B5](scenarios/B5-split-column) | Split a column (`full_name` → `first_name`, `last_name`) | Shared split functions in trigger and backfill |
| [B6](scenarios/B6-split-table) | Split a table (`customer.address_*` → `address`) | Two-table sync without trigger loops (`pg_trigger_depth`) |
| [B7](scenarios/B7-cardinality-1-1-to-1-n) | Change cardinality 1:1 → 1:N | Partial unique index "one primary per customer", PK swap `USING INDEX` |
| [B8](scenarios/B8-merge-tables) | Merge two tables into one | Old table replaced by a view with `INSTEAD OF` triggers |
| [B9](scenarios/B9-pk-int-to-bigint) | Widen a PK `int` → `bigint` with referencing FKs | Shadow columns, batched backfill, concurrent indexes, metadata-only swap |
| [B10](scenarios/B10-drop-column-table) | Drop a column or table | Find dependents, soft-drop by rename, drop without `CASCADE` |
| [B11](scenarios/B11-partition-existing-table) | Partition an existing large table | Zero-copy: the old table becomes the first partition; validated `CHECK` lets `ATTACH PARTITION` skip the scan; PK must include the partition key |
| [B12](scenarios/B12-enum-to-lookup-table) | Remove an enum value (enum → lookup table) | No `DROP VALUE` in PostgreSQL; lookup table + FK + sync trigger, the value is retired with a `DELETE` |

### C. Team operations

How migrations break in day-to-day team work, independent of the SQL inside them.

| ID | Scenario | Key point |
|---|---|---|
| [C1](scenarios/C1-branch-version-conflict) | Two branches create the same version; a lower version merged after a higher one ran | Renumber before it reaches a shared database; `-outOfOrder=true` and its execution-order catch |
| [C2](scenarios/C2-checksum-mismatch) | Someone edits an applied migration | Checksum mismatch blocks every deploy; `repair` only for cosmetic edits, otherwise revert + new migration |

### D. Data migrations

| ID | Scenario | Why it matters |
|---|---|---|
| [D1](scenarios/D1-seed-reference-data) | Reference/seed data | Versioned vs `R__` repeatable, desired-state upsert |
| [D2](scenarios/D2-batched-backfill) | Batched backfill of a large table | Key-range batches, `COMMIT` per batch, throttling |
| [D3](scenarios/D3-cleanup-before-constraint) | Cleanup before FK / CHECK / NOT NULL | Constrain `NOT VALID` → clean → validate, quarantine unfixable rows |
| [D4](scenarios/D4-deduplication) | Deduplication before a UNIQUE constraint | Survivor map, repoint children (with their own unique keys), delete |
| [D5](scenarios/D5-normalization-lookup-table) | Normalization: free text → lookup table + FK | One normalization key everywhere |
| [D6](scenarios/D6-denormalization-counter-cache) | Denormalization / counter cache | Trigger + absolute backfill + reconciliation |
| [D7](scenarios/D7-value-remapping) | Value remapping (legacy codes → new codes) | Mapping table, pre-flight assertion, conditional rules |
| [D8](scenarios/D8-format-normalization) | Format normalization (email, name, E.164 phone) | Rules as `IMMUTABLE` functions reused by `CHECK`s |
| [D9](scenarios/D9-unit-semantic-conversion) | `timestamp` → `timestamptz`, float money → cents | Silent corruption: `USING ... AT TIME ZONE`, `round()` |
| [D10](scenarios/D10-quarantine-failed-rows) | Quarantine table for failed conversions | `pg_input_is_valid()`, quality gate |
| [D11](scenarios/D11-jsonb-columns) | JSONB ↔ columns | Handle every JSON shape, single source of truth |
| [D12](scenarios/D12-archive-old-data) | Archive/move old data | `DELETE ... RETURNING` → `INSERT` in one statement, `SKIP LOCKED` |
| [D13](scenarios/D13-int-to-uuid-public-id) | Int → UUID public identifier | Add + default + batched backfill + concurrent unique, no rewrite |
| [D14](scenarios/D14-resumable-migration) | Resumable migration | Checkpoint table, procedure with `COMMIT`, `flyway repair` |
| [D15](scenarios/D15-bulk-load-drop-recreate) | Bulk load: drop indexes/FKs/triggers, load, recreate | Pre-check staging data, rebuild, `ANALYZE` |
| [D16](scenarios/D16-post-migration-verification) | Post-migration verification | Counts, totals, per-row fingerprints, rollback on mismatch |

The data scenarios show what *can* be done with Flyway, mainly as techniques. At real-world volume and complexity, that work moves into a separate, custom-SQL process like [`/full-custom-migration`](../full-custom-migration), which reuses D1, D2, D3, D4, D5, D7, D8, D9, D10, D14, D15 (partly) and D16.

## Limitations and Gaps

The biggest gaps are not in the SQL.<br>
They are in how migrations are run as a team process: rollback, environment-specific changes, and running migrations from the app.<br>
The second gap is a few common PostgreSQL schema changes.

### Missing scenarios

Covered since this list was written: partitioning an existing table (**B11**), removing an enum value (**B12**).

1. **Changing a FK's `ON DELETE` behavior, or switching a natural key to a surrogate key.** Both come up often in real projects.
2. **Shrinking a column** (`varchar(255)` → `varchar(50)`) when existing data is longer than the new limit.

### Team process

Covered since this list was written: version conflicts between branches and `outOfOrder` (**C1**), editing an applied migration (**C2**). Still without a scenario:

1. **Rollback.** Flyway OSS has no undo (`U__` migrations are a paid feature), so the approach is forward-fix: a new migration that corrects the previous one (shown in **C2**). Liquibase rollback: [L22](../liquibase/scenarios/L22-rollback-and-contexts).
2. **Environment-specific changes.** Placeholders or separate `locations`, e.g. test data only in dev.
3. **Migrations run on app startup by several instances at once.** Flyway's lock on the history table, and deploy timeouts on long migrations.
4. **Versioning views, functions and procedures with `R__` migrations.** The [main README](../README.md) discusses this, but D1 uses `R__` only for reference data.

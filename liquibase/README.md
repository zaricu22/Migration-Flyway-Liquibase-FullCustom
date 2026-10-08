# Liquibase across PostgreSQL, MySQL, SQL Server — cross-engine syntax conflicts

Most migration tutorials stop at `CREATE TABLE` and `ADD COLUMN`.<br>
Real migrations fail on other things: locks on large tables, dirty data that breaks a new constraint, duplicates that block a unique index, renames that break the running application, or SQL that works on one engine and fails on another.

**Cross-engine syntax conflicts** (23 scenarios) for **Liquibase 4.33 (OSS)** on **PostgreSQL 17, MySQL 8.4 and SQL Server 2022**:

- Data types
- Auto-generation and defaults
- Identifiers and keywords
- Statement and behavior differences
- Team operations (rollback, contexts and labels)

They target one of the classic reasons migrations fail in production: SQL that works on one engine and fails on another, and show how one changelog handles all three engines.

Each scenario isolates one conflict, mainly to demonstrate what Liquibase can do: changesets, preconditions, `dbms` variants, properties, quoting strategies, and so on.

In short: Liquibase is primarily for **schema changes (DDL)** and the small data changes that belong to them, like reference data (currencies, statuses, countries) and backfills.

For the common theory (database versioning, what belongs in migrations, considerations), see the [main README](../README.md).

<!-- contents -->
**Contents**

- [Principles](#principles)
- [Running](#running)
- [Layout](#layout)
- [Scenarios](#scenarios)
  - [Top 5 most complex scenarios](#top-5-most-complex-scenarios)
  - [Data types](#data-types)
  - [Auto-generation and defaults](#auto-generation-and-defaults)
  - [Identifiers and keywords](#identifiers-and-keywords)
  - [Statement and behavior differences](#statement-and-behavior-differences)
  - [Team operations](#team-operations)
- [Limitations and Gaps](#limitations-and-gaps)
<!-- /contents -->

## Principles

Each scenario runs **one changelog (identical in YAML and XML)** against all three engines. The conflicts are resolved with Liquibase's cross-engine tools:

- **abstract types** (`boolean`, `uuid`, `autoIncrement`, ...), mapped per engine by Liquibase
- **`property` with `dbms`**: `${json_type}`, `${now6}` resolved per engine
- **`dbms` on a changeset**: engine-specific variants of the same step
- **`objectQuotingStrategy`**: reserved words and case
- **`preConditions`**: re-runnable changesets

Also:
- **One scenario = one folder = one database per engine** (`l1`, `l2`, ...). By default it's dropped and re-created on every run.
- **Every scenario is verifiable.** `inspect/<engine>.sql` shows the resulting types and data per engine, next to the common column/type report.
- **Every claim was run.** Each scenario README describes the observed behavior per engine, including the surprises. Exception: **L21, L22 and L23** were added later and haven't been run yet; their READMEs say so and describe the expected behavior.

## Running

Requirements: Docker with Compose. On Windows, use `run.ps1` (PowerShell) or `run.sh` (Git Bash). Both take the same arguments. Images are pulled on the first run. SQL Server needs about 2 GB RAM.

```bash
./run.sh L1                     # all engines, YAML: reset DB -> update -> inspect
./run.sh L1 mysql xml           # one engine, XML
./run.sh L8 mssql yaml sql      # only print the SQL Liquibase would generate
./run.sh L20 all yaml rerun     # update WITHOUT reset (e.g. after editing a runOnChange view)
CHANGELOG=failure-demo ./run.sh L19      # use another changelog file in the scenario folder
LB_ARGS=--context-filter=prod ./run.sh L22                # extra Liquibase options
LB_ARGS=--tag=v1 ./run.sh L22 postgres yaml rollback      # any other Liquibase command, without reset
```
(PowerShell: `$env:CHANGELOG = "failure-demo"; .\run.ps1 L19`, `$env:LB_ARGS = "--tag=v1"; .\run.ps1 L22 postgres yaml rollback`)

**GUI clients:**

- PostgreSQL `localhost:5434` demo/Demo_Pass123
- MySQL `localhost:3307` root/Demo_Pass123
- SQL Server `localhost:1434` sa/Demo_Pass123

**Stop everything:** `docker compose down -v`.

> The official `liquibase/liquibase` image doesn't bundle the MySQL JDBC driver (licensing). `docker-compose.yml` builds a small derived image with `lpm add mysql` once, instead of downloading the driver on every run (`INSTALL_MYSQL=true`).

> [!NOTE]
> How a scenario actually runs (`./run.sh <ID> [engine] [format] [mode]`):
>
> 0. **Everything runs in Docker.** PostgreSQL, MySQL and SQL Server run as containers (engines), and Liquibase runs as a short-lived container for each command (`docker compose run --rm`). 
> <br>The `./scenarios` folder is mounted into all of them, read-only; `./common` only into the three database containers, where the inspect scripts run.
> <br> **Main source**: `./scenarios/<ID>/changelog.yaml[xml]`
> 1. **`update`** (default action; execute same steps on every selected engine `all (default)|postgres|mysql|mssql`): 
>   - resets the scenario's database on that engine (drop + create), 
>   - runs `liquibase update` in the Liquibase container with the scenario folder as `--search-path`, the changelog as `--changelog-file` (`changelog.yaml` / `.xml`) and the engine's database as `--url`, 
>   - inspects the result with the engine's own client (`psql`, `mysql`, `sqlcmd`): 
>     - `common/inspect-<engine>.sql` (show every created column with the real type on that engine) 
>     - the scenario's `inspect/<engine>.sql` (specific checks for that scenario on that engine).
> 2. The other modes are variations of step 1: 
>   - `rerun` skips the reset, 
>   - `sql` only prints the SQL that Liquibase would generate (`update-sql`), 
>   - `inspect` only inspects, 
>   - other Liquibase command (`rollback`, `tag`, `history`, ...) runs without a reset, then inspects.

## Layout

```
liquibase/
├── docker-compose.yml                 # postgres (5434), mysql (3307), mssql (1434) + liquibase image
├── run.sh | run.ps1                   # ./run.sh <ID> [all|postgres|mysql|mssql] [yaml|xml] [update|rerun|sql|inspect|<command>]
├── common/inspect-<engine>.sql        # column/type report, run after every update
└── scenarios/
    └── L1-boolean/
        ├── README.md                  # the conflict, per-engine result, chosen solution
        ├── changelog.yaml             # the same changesets in both formats
        ├── changelog.xml
        └── inspect/
            ├── postgres.sql           # scenario-specific checks per engine
            ├── mysql.sql
            └── mssql.sql
```

## Scenarios

### Top 5 most complex scenarios

Ranked by how many steps they take and how much can go wrong in production:

| # | Scenario | Why it's complex |
|---|---|---|
| 1 | [L19](scenarios/L19-transactional-ddl): transactional DDL | MySQL commits each DDL statement on its own, so a failed changeset leaves half its changes behind and blocks re-runs. The portable fix is one DDL per changeset plus preconditions |
| 2 | [L14](scenarios/L14-rename-modify-column): rename / modify a column | The generated SQL silently drops `NOT NULL` and `DEFAULT` on MySQL and SQL Server. The constraints have to be restated per engine, and the default must not be added twice on SQL Server |
| 3 | [L17](scenarios/L17-case-insensitive-unique): case-insensitive unique e-mail | Collations differ in how they handle case, accents and trailing spaces, so the "same" unique rule accepts different data on each engine |
| 4 | [L20](scenarios/L20-dialect-functions-in-views): dialect functions in views | Different string, date and `LIMIT`/`TOP` syntax per engine, `dbms`-specific view definitions, and `runOnChange` to keep views versioned |
| 5 | [L9](scenarios/L9-current-time-default): current-time defaults and automatic `updated_at` | Precision and default syntax differ per engine; MySQL has `ON UPDATE`, PostgreSQL and SQL Server need triggers, and SQL Server needs its own batching |

Next in line: [L23](scenarios/L23-mssql-unique-null-cascade-paths) (SQL Server unique with NULLs and multiple cascade paths) and [L22](scenarios/L22-rollback-and-contexts) (rollback, contexts and labels). Both haven't been run yet.

### Data types

| ID | Conflict | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|---|
| [L1](scenarios/L1-boolean) | Boolean (type + literals) | `boolean`, `TRUE` | `TINYINT`, `1` | `bit`, `1` |
| [L2](scenarios/L2-large-text-unicode) | Large text & Unicode | `text` | `longtext` (`TEXT` = 64 KB) | `nvarchar(max)` (`varchar` loses Unicode) |
| [L3](scenarios/L3-uuid) | UUID | `uuid` | `char(36)` (no validation) | `uniqueidentifier` (different sort order) |
| [L4](scenarios/L4-json) | JSON | `jsonb` | `json` | `nvarchar(max)` + `ISJSON` check |
| [L5](scenarios/L5-timestamp-timezone) | Timestamp with time zone | `timestamptz` | `datetime(6)` + UTC convention | `datetimeoffset` |
| [L6](scenarios/L6-binary-data) | Binary data | `bytea` (abstract `blob` = `oid`!) | `longblob` | `varbinary(max)` |
| [L7](scenarios/L7-enum) | Enum | `CREATE TYPE ... AS ENUM` | inline `ENUM(...)` | `varchar` + `CHECK` |

### Auto-generation and defaults

| ID | Conflict | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|---|
| [L8](scenarios/L8-auto-increment) | Auto-increment, sequences | `GENERATED BY DEFAULT AS IDENTITY` | `AUTO_INCREMENT` (no `incrementBy`) | `IDENTITY(start, step)` |
| [L9](scenarios/L9-current-time-default) | Current-time defaults, auto `updated_at` | `now()` + trigger | `CURRENT_TIMESTAMP(6)` + `ON UPDATE` | `SYSDATETIME()` + trigger |
| [L10](scenarios/L10-uuid-default) | UUID default | `gen_random_uuid()` (v4) | `(UUID())` (v1) | `NEWID()` / `NEWSEQUENTIALID()` |

### Identifiers and keywords

| ID | Conflict | Details |
|---|---|---|
| [L11](scenarios/L11-reserved-words) | Reserved words as names (`user`, `order`, `group`, `key`) | Quoted automatically in change types, but not in raw SQL or the `references:` shorthand |
| [L12](scenarios/L12-case-sensitivity) | Case sensitivity | Liquibase quotes CamelCase on PostgreSQL; MySQL table names are case-sensitive on Linux |
| [L13](scenarios/L13-identifier-length) | Identifier length limits | PostgreSQL truncates to 63, which silently breaks an `indexExists` precondition |

### Statement and behavior differences

| ID | Conflict | Details |
|---|---|---|
| [L14](scenarios/L14-rename-modify-column) | Rename/modify column | MySQL `CHANGE`/`MODIFY` and SQL Server `ALTER COLUMN` drop `NOT NULL` / `DEFAULT` |
| [L15](scenarios/L15-upsert) | Upsert | `loadUpdateData` vs `ON CONFLICT` / `ON DUPLICATE KEY` / `MERGE` |
| [L16](scenarios/L16-partial-index) | Partial/filtered index | PostgreSQL and SQL Server `WHERE`, MySQL generated-column workaround |
| [L17](scenarios/L17-case-insensitive-unique) | Case-insensitive unique email | Collations: case, accents and trailing spaces behave differently |
| [L18](scenarios/L18-computed-columns) | Generated/computed columns | Syntax, immutability rules, inferred types |
| [L19](scenarios/L19-transactional-ddl) | Transactional DDL | MySQL leaves half-applied changesets. One DDL per changeset + preconditions |
| [L20](scenarios/L20-dialect-functions-in-views) | Dialect functions in views | `CONCAT` vs `CONCAT_WS`, `\|\|`, date math, `LIMIT`/`TOP`, `runOnChange` |
| [L21](scenarios/L21-mssql-default-constraint-drop) | Drop a column that has a default | SQL Server: the default is a constraint with a generated `DF__...` name and blocks the drop. `dropDefaultValue` first, name new defaults |
| [L23](scenarios/L23-mssql-unique-null-cascade-paths) | Unique with NULLs, multiple cascade paths | SQL Server: one NULL per unique column (filtered index instead), and no two `ON DELETE CASCADE` paths to one table |

### Team operations

| ID | Topic | Details |
|---|---|---|
| [L22](scenarios/L22-rollback-and-contexts) | Rollback blocks, contexts and labels | Automatic vs explicit rollback, rollback restores structure not data; without a context filter **all** changesets run, test data included |

## Limitations and Gaps

The biggest gaps are not in the SQL.<br>
They are in how migrations are run as a team process: merge conflicts, edited changesets, and running migrations from the app.<br>
The second gap is a few well-known MySQL and cross-engine problems.

### Missing scenarios

Covered since this list was written: dropping a column with a default (**L21**), multiple cascade paths and unique with NULLs (**L23**).

1. **MySQL: index key length limit with `utf8mb4`** (3072 bytes). A unique index on `varchar(1000)` works on PostgreSQL and fails on MySQL.
2. **Stored procedures and triggers in changelogs.** `endDelimiter`/`splitStatements`, `GO`, `DELIMITER` across engines. L9 touches on this, but there's no dedicated scenario.
3. **Decimal and float precision** across engines.

### Team process

Covered since this list was written: rollback blocks, contexts and labels (**L22**). Still without a scenario:

1. **Changesets from parallel branches.** Changesets are identified by `id` + `author` + file, so numbers don't collide, but merge conflicts in the changelog and the order of `include`/`includeAll` still need care.
2. **Someone edits a changeset that has already been applied.** The checksum no longer matches. The fix is a new changeset, or `validCheckSum` when the change is intentional. The Flyway equivalent is shown in [C2](../flyway/scenarios/C2-checksum-mismatch).
3. **Migrations run on app startup by several instances at once.** The `DATABASECHANGELOGLOCK` table (and a lock left behind by a killed process, cleared with `release-locks`), and deploy timeouts on long migrations.
4. **Versioning views, functions and procedures with `runOnChange`.** The [main README](../README.md) discusses this, but only L20 demonstrates it.

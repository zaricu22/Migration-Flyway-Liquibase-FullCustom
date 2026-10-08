# C1 — Branch version conflict and out-of-order migrations

**Goal:** handle the most common Flyway problem in teams: two branches that create migrations with the **same version number**, and a branch that is merged **after** a higher version is already in production.

> **Not yet run against the containers.** The behavior below is the expected Flyway 11 behavior; run the commands to confirm it.

| Folder | Represents | Files |
|---|---|---|
| `migrations/` | `main` after a correct merge | `V1__setup`, `V2__add_phone` (developer A), `V3__index_customer_email` (developer B, **renumbered**) |
| `branch-b/` | developer B's original branch | `V2__index_customer_email`: also version 2 |
| `late/` | developer C's long-running branch | `V2_1__add_country`: version 2.1, merged after V3 is in production |

The folders are combined with the `LOCATIONS` variable of `run.sh` (one Flyway location per folder).

## Case 1: two branches, the same version

Developers A and B both branch off when V1 is the latest version, and both create **V2**. Each branch works on its own. After merging, Flyway sees both files:

```
LOCATIONS=migrations,branch-b ./run.sh C1 migrate
ERROR: Found more than one migration with version 2
```

Nothing runs, on any database. **Fix:** the branch merged second renumbers its migration to the next free version (`branch-b/V2__...` → `migrations/V3__...`).
- Renumbering is safe only while the migration hasn't run on any shared database (test, staging). Once it is in a history table, renaming it creates a new, unknown migration there.
- **Prevention:** CI runs `flyway validate` (or a simple duplicate-version check) on every pull request against the target branch, so the conflict shows up before the merge, not in the deployment.

## Case 2: a lower version arrives after a higher one ran

Production already has V1, V2 and V3. Developer C's branch, started earlier, brings **V2.1**:

```
./run.sh C1 migrate                                   # V1, V2, V3 applied
LOCATIONS=migrations,late ./run.sh C1 migrate
ERROR: Validate failed: Migrations have failed validation
Detected resolved migration not applied to database: 2.1
```

By default Flyway refuses: a version lower than the latest applied one is treated as a mistake. The options:

| Option | Effect | Use when |
|---|---|---|
| Renumber to V4 | Runs in order, everywhere | The default choice. Possible as long as V2.1 hasn't run on a shared database |
| `-outOfOrder=true` | Applies V2.1 *after* V3; `info` shows it as `Out of Order` | Hotfix branches, or teams that use timestamps as versions (`V20260930_1412__...`), where out-of-order is normal |
| `-ignoreMigrationPatterns='*:ignored'` | Doesn't fail, but doesn't apply V2.1 either | Almost never: the migration is silently skipped |

```
LOCATIONS=migrations,late FLYWAY_ARGS=-outOfOrder=true ./run.sh C1 migrate     # 2.1 applied
LOCATIONS=migrations,late ./run.sh C1 info                                      # 2.1: Out of Order
```

**The catch with out-of-order:** the real order of execution differs between databases. Production runs V3 → V2.1, but a fresh database (a new developer, CI) runs V2.1 → V3. That's only safe if the two migrations are **independent** (here: a new column vs an index on another column). `installed_rank` in `flyway_schema_history` shows the order in which they really ran.

## Run

```bash
./run.sh C1 clean
LOCATIONS=migrations,branch-b ./run.sh C1 migrate                              # fails: two version 2
./run.sh C1 all                                                                # the renumbered merge works
LOCATIONS=migrations,late ./run.sh C1 migrate                                  # fails: 2.1 is out of order
LOCATIONS=migrations,late FLYWAY_ARGS=-outOfOrder=true ./run.sh C1 migrate     # applied after V3
LOCATIONS=migrations,late ./run.sh C1 info
./run.sh C1 verify
```
PowerShell: `$env:LOCATIONS = "migrations,late"; $env:FLYWAY_ARGS = "-outOfOrder=true"; .\run.ps1 C1 migrate` (clear them afterwards with `Remove-Item Env:LOCATIONS, Env:FLYWAY_ARGS`).

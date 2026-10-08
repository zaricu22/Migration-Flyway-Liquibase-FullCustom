# C2 — Checksum mismatch after editing an applied migration

**Goal:** show what happens when someone edits a migration that has already run, why `repair` is usually the wrong fix, and what the right fix is.

> **Not yet run against the containers.** The behavior below is the expected Flyway 11 behavior; run the commands to confirm it.

Flyway stores a **checksum** (CRC32 of the file content) for every applied migration in `flyway_schema_history`. Before each `migrate`, it validates the files against the history (`validateOnMigrate=true` by default).

| Folder | Represents | V2 |
|---|---|---|
| `migrations/` | the repository when V2 was applied | `DEFAULT 'new'` |
| `edited/` | someone changed the applied V2 | `DEFAULT 'open'` (**behavior change**) |
| `cosmetic/` | someone added a comment to the applied V2 | `DEFAULT 'new'` + a comment (same SQL) |
| `fixed/` | the right way: a new migration | `V3__change_status_default.sql` (combined with `migrations/`) |

`edited/` and `cosmetic/` also contain an unchanged copy of V1: each folder is "the whole repository" at that moment.

## What happens

```
./run.sh C2 all                                  # V1, V2 applied: default 'new'
LOCATIONS=edited ./run.sh C2 validate
ERROR: Validate failed: Migrations have failed validation
Migration checksum mismatch for migration version 2
-> Applied to database : <old checksum>
-> Resolved locally    : <new checksum>
```

`migrate` fails the same way, so **every deployment is blocked** until it's resolved. That is intended: the database ran a different V2 than the one in the repository.

## The fixes

| Situation | Fix | Why |
|---|---|---|
| The edit changes **behavior** (`edited/`) | **Revert the edit** and put the change into a **new migration** (`fixed/V3`) | Old and fresh databases reach the same state by the same path |
| The edit is **cosmetic**: comment, formatting (`cosmetic/`) | `repair` | Updates the stored checksum to the file's. Nothing is executed, and nothing needs to be |
| The edit fixes a migration that **failed** and never completed | `repair` removes the failed entry, then `migrate` again | See **A4** / **D14** |

**Why `repair` is wrong for a behavior change:**
```
LOCATIONS=edited ./run.sh C2 repair              # "Repairing ... checksum" -> history now matches the edited file
LOCATIONS=edited ./run.sh C2 migrate             # "Schema is up to date": nothing runs
./run.sh C2 verify                               # default is still 'new'
```
The validation error is gone, but the edited SQL **never ran** on this database. A fresh database built from the same files gets `'open'`. The environments have silently drifted apart, and nothing reports it anymore.

**The right fix:**
```
./run.sh C2 clean && ./run.sh C2 migrate         # back to the original state ('new')
LOCATIONS=migrations,fixed ./run.sh C2 migrate   # V3 runs: default 'open' everywhere
./run.sh C2 verify
```

## Key points
- **An applied migration is never edited.** Make that a review rule; CI can enforce it with `flyway validate` against a copy of production's history.
- The checksum covers the whole file, so even a comment or whitespace change trips validation. Line endings are normalized, so a CRLF ↔ LF conversion by git does not.
- Liquibase has the same check (`MD5SUM` in `DATABASECHANGELOG`). Its equivalents are `clear-checksums` (like `repair`) and `<validCheckSum>` on a changeset, which accepts a specific old checksum. The same rule applies: only for edits that don't change behavior.
- `R__` repeatable migrations are the exception by design: a changed checksum makes them **run again** (see **D1**).

## Run

```bash
./run.sh C2 all
LOCATIONS=edited ./run.sh C2 validate            # checksum mismatch
LOCATIONS=cosmetic ./run.sh C2 validate          # mismatch too: comments count
LOCATIONS=cosmetic ./run.sh C2 repair            # legitimate: SQL unchanged
LOCATIONS=cosmetic ./run.sh C2 validate          # passes
./run.sh C2 clean && ./run.sh C2 migrate
LOCATIONS=migrations,fixed ./run.sh C2 migrate   # the right fix
./run.sh C2 verify
```
PowerShell: `$env:LOCATIONS = "edited"; .\run.ps1 C2 validate` (clear it afterwards with `Remove-Item Env:LOCATIONS`).

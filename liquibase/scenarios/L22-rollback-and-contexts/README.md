# L22 — Rollback blocks, contexts and labels

**Topic:** two Liquibase features that Flyway OSS doesn't have. **Rollback**: undo changesets, back to a tag or by count. **Contexts and labels**: choose at runtime which changesets run, e.g. test data only in dev. Both work the same on all three engines; the scenario runs on each to show it.

> **Not yet run against the containers.** The results below are the expected Liquibase 4.33 behavior; run the commands to confirm them.

## Rollback

| Change type | Rollback |
|---|---|
| `createTable`, `addColumn`, `createIndex`, `renameColumn`, ... | **automatic** (Liquibase knows the inverse) |
| `sql`, `insert`, `update`, `delete`, `dropTable`, `dropColumn`, ... | **explicit `rollback:` block required** |
| A change that needs no undo | `rollback: []` (YAML) / `<rollback/>` (XML): rolling back does nothing, on purpose |

```
./run.sh L22 postgres                                       # v1 + tag v1 + v2 + test data
LB_ARGS=--tag=v1 ./run.sh L22 postgres yaml rollback        # 7 -> 6 -> 5 -> 4 undone, in reverse order
```
After the rollback: no `price`, no view, no test rows, and `legacy_code` is back, but **empty**.

**Key points**
- **Rollback restores structure, not data.** Rolling back `dropColumn` re-adds the column; the values are gone. For destructive changes, take a backup, or keep the data in a copy until the release is confirmed.
- **A changeset without an inverse blocks the rollback.** `failure-demo.yaml` has a raw SQL changeset without a rollback block: rolling back to `v1` fails with a `RollbackImpossibleException` ("No inverse to ... RawSQLChange").
- **Tag every release** (`tagDatabase`, or the `tag` command after `update`), so `rollback --tag=<release>` has a target. Alternatives: `rollback-count --count=<n>`, `rollback-to-date`.
- **Preview first:** `rollback-sql` prints the SQL without running it.
- **Test the rollback in CI:** `update-testing-rollback` runs update → rollback → update, and fails if any rollback block is missing or wrong.
- **Flyway OSS has no rollback.** "Undo" migrations (`U2__...`) are a paid Flyway feature. The usual Flyway approach is **fix forward**: a new migration that corrects the previous one (see Flyway **C2**). Many teams use fix-forward with Liquibase too, and treat rollback as a dev / test tool.

## Contexts and labels

| | Contexts | Labels |
|---|---|---|
| Set on the changeset | `context: dev` (an expression: `dev or test`, `!prod`) | `labels: v2` (a list of tags) |
| Chosen at runtime | `--context-filter=dev` | `--label-filter=v1` (an expression: `v1 or v2`, `!v2`) |
| Typical use | **Where** it runs: environments (test data only in dev) | **What** is deployed: releases, features, tickets |

```
./run.sh L22 postgres                                               # no filter: test data INCLUDED (!)
LB_ARGS=--context-filter=prod ./run.sh L22 postgres                 # test data skipped
LB_ARGS=--context-filter=dev ./run.sh L22 postgres                  # test data included
LB_ARGS=--label-filter=v1 ./run.sh L22 postgres                     # only release v1 (+ unlabeled changesets)
```

**Key points**
- **No filter = everything runs.** A changeset with `context: dev` runs whenever no context filter is given. Production deployments must therefore **always** pass `--context-filter` (e.g. `prod`), or test data ends up in production.
- **Changesets without a label always run**, whatever the label filter; the same applies to contexts. Here, `--label-filter=v1` also runs the tag changeset and the (unlabeled) test data changeset.
- `DATABASECHANGELOG` records the contexts and labels each changeset ran with (scenario inspect).
- Flyway has no direct equivalent. The usual Flyway approach is separate locations per environment (`-locations=db/migration,db/testdata`) or placeholders.

## Run

```bash
./run.sh L22                                                  # all engines, no filter
LB_ARGS=--context-filter=prod ./run.sh L22                    # without test data
LB_ARGS=--tag=v1 ./run.sh L22 all yaml rollback               # back to release v1
LB_ARGS=--tag=v1 ./run.sh L22 postgres yaml rollback-sql      # only print the rollback SQL
CHANGELOG=failure-demo ./run.sh L22 postgres
CHANGELOG=failure-demo LB_ARGS=--tag=v1 ./run.sh L22 postgres yaml rollback   # RollbackImpossibleException
```
PowerShell: `$env:LB_ARGS = "--tag=v1"; .\run.ps1 L22 postgres yaml rollback` (clear it afterwards with `Remove-Item Env:LB_ARGS`).

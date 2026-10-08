#!/usr/bin/env bash
# Orchestrates the migration pipeline: runs the phase folders in order, one transaction per file,
# records every phase in mig.run_phase, and STOPS at the first failed file or gate.
#
# Usage: ./run.sh <command>
#   source       (re)create the OLD system (database legacy_shop) with its intentionally dirty data
#   assess       profile the old system (00_assess): volumes, formats, orphans, duplicates. Read-only

#   all          full run: setup -> extract -> validate -> transform -> reconcile -> load -> verify
#   setup        create both databases and run all 00_setup scripts (mig schema, tables, rules, ...)
#   extract | validate | transform | reconcile | load | verify
#                run ONE phase again within the current run (e.g. after fixing a rule)
#   delta        change data in the old system, then incremental extract + validate .. verify
#   cutover      freeze the old system, final delta + validate .. verify, smoke test, go/no-go gate
#   unfreeze     NO-GO: make the old system writable again (07_cutover/729)
#   report       findings, check results and phase history of the current run-
#   archive      save the report + every mig table as files in archive/<timestamp>/
#   rollback     remove everything the migration loaded into production (07_cutover/790)
#   cleanup      archive, then drop raw / stg / src after go-live, keep the mig audit trail (08_cleanup/810)
#   reset        drop the NEW system (database shop) to start over; the old system stays
#   psql [db]    interactive session (db: shop (default) | legacy_shop)
set -uo pipefail            # no -e: failures are handled explicitly (phase marked FAILED, then exit)
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: don't rewrite /migration/... into C:/...
cd "$(dirname "$0")"

# 1st parameter, required: the command (2nd parameter only for psql: the database)
cmd="${1:?usage: ./run.sh source|assess|all|setup|extract|validate|transform|reconcile|load|verify|delta|cutover|unfreeze|report|archive|rollback|cleanup|reset|psql}"

# Make sure the database container is running and ready before any script touches it.
#   docker compose   │ Works with the services defined in docker-compose.yml in the current folder
#   --progress quiet │ Hides the progress output
#   up               │ Creates and starts the service; does nothing if it's already running
#   -d               │ Detached mode (run in background)
#   --wait           │ Waits until the container is healthy before returning, using the healthcheck from the compose file
#   postgres         │ The only service: one PostgreSQL with both databases (legacy_shop = old, shop = new)
docker compose --progress quiet up -d --wait postgres || exit 1

# Run one SQL file. One transaction per file (-1), except *_batched*.sql: those COMMIT themselves.
#   Params:
#     $1 database,
#     $2 sql script file (relative to full-custom-migration/, mounted in the container as /migration)
#   exec -T            │ Runs psql in the running container, no pseudo-terminal (output can be piped/filtered)
#   psql -U -d         │ user and database
#   -q                 │ quiet: no "INSERT 0 1"-style status messages (results, \echo and NOTICEs still shown)
#   -v ON_ERROR_STOP=1 │ stop at the first error with a non-zero exit code (a failed gate stops the pipeline)
#   -1 ($single)       │ run the whole file as ONE transaction: an error leaves nothing half-done
#   -f                 │ the file to run (path inside the container)
run_file() {
  local single="-1"
  [[ "$2" == *_batched* ]] && single=""
  echo "---- $2"
  docker compose exec -T postgres psql -U demo -d "$1" -q -v ON_ERROR_STOP=1 $single -f "/migration/$2"
}

# Run one bookkeeping SQL statement (mig.phase_start, CREATE DATABASE, ...).
#   Params:
#     $1 database,
#     $2 statement to run
#   -qtA               │ quiet, tuples only (no headers), unaligned: bare values
#   -c                 │ the statement to run
#   >/dev/null         │ output suppressed; only the exit code matters
sql() {
  docker compose exec -T postgres psql -U demo -d "$1" -qtA -v ON_ERROR_STOP=1 -c "$2" >/dev/null
}

# Does database $1 exist? (queried from the maintenance database "postgres")
#   -tAc               │ tuples only, unaligned, run the statement: prints just "1" or nothing
db_exists() {
  [ "$(docker compose exec -T postgres psql -U demo -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$1'")" = "1" ]
}

# Create the OLD system on first use (the source/legacy_shop.sql script fills it with intentionally dirty data)
ensure_legacy_source() {
  db_exists legacy_shop || { sql postgres "CREATE DATABASE legacy_shop" && run_file legacy_shop source/legacy_shop.sql; }
}

# Create the NEW system's empty database on first use
ensure_shop() {
  db_exists shop || sql postgres "CREATE DATABASE shop"
}

# Setup: both databases + every 00_setup script (all idempotent, safe to re-run). Not logged in
# mig.run_phase: the mig schema itself is created here.
run_setup() {
  ensure_legacy_source; ensure_shop
  echo "==== 00_setup"
  for f in 00_setup/*.sql; do
    run_file shop "$f" || { echo ">>> SETUP FAILED"; exit 1; };
  done
}

# Run all files of a phase folder (or the given files) and record the outcome in mig.run_phase.
#   Params:
#     $1 phase name,
#     $2.. files (default: all *.sql in the folder named like the phase, in name order)
#   mig.phase_start    │ phase RUNNING (re-opens a FAILED run when a phase is retried)
#   mig.phase_end      │ DONE, or FAILED at the first failing file -> the pipeline stops (exit 1)
run_phase() {
  local phase="$1"; shift
  local files=("$@")
  [ ${#files[@]} -eq 0 ] && files=("$phase"/*.sql)
  echo "==== $phase"
  sql shop "SELECT mig.phase_start('$phase')" || exit 1
  for f in "${files[@]}"; do
    if ! run_file shop "$f"; then
      sql shop "SELECT mig.phase_end('$phase', 'FAILED')"
      echo ">>> PHASE $phase FAILED in $f. The pipeline stops here (see ./run.sh report)."
      exit 1
    fi
  done
  sql shop "SELECT mig.phase_end('$phase', 'DONE')"
}

# Mapping: command name -> phase folder
phase_dir() {
  case "$1" in
    extract) echo 01_extract ;; validate) echo 02_validate ;; transform) echo 03_transform ;;
    reconcile) echo 04_reconcile ;; load) echo 05_load ;; verify) echo 06_verify ;;
  esac
}

# The report: all runs, phase durations, findings per rule and every check of the current run. Read-only.
# Used by "report" (to the screen) and "archive" (to a file).
#   <<'SQL'            │ queries passed to psql on stdin (here-document; quoted, so the shell changes nothing)
report() {
  docker compose exec -T postgres psql -U demo -d shop -q <<'SQL'
\echo '=== Runs'
SELECT run_id, kind, status, started_at::timestamp(0), finished_at::timestamp(0) FROM mig.run ORDER BY run_id;
\echo '=== Phases of the current run'
SELECT phase, status, round(extract(epoch FROM finished_at - started_at)::numeric, 1) AS seconds
FROM mig.run_phase WHERE run_id = mig.current_run() ORDER BY started_at;
\echo '=== Findings of the current run (records per rule)'
SELECT entity, severity, rule, count(DISTINCT source_key) AS records
FROM mig.error WHERE run_id = mig.current_run() GROUP BY 1, 2, 3 ORDER BY 1, 2, 3;
\echo '=== Checks of the current run'
SELECT phase, check_name, ok, expected, actual FROM mig.reconciliation
WHERE run_id = mig.current_run() ORDER BY phase, check_name;
SQL
}

# Archive the audit trail OUTSIDE the database (part of 8 CLEANUP): the report as text, and every mig
# table as CSV, in archive/<timestamp>/ next to this script. Returns non-zero if anything fails.
#   COPY ... TO STDOUT │ the server streams the table to psql; the shell redirects it into a file on the host
#   FORMAT csv, HEADER │ one CSV file per table, with column names
archive_reports() {
  local dir="archive/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$dir" || return 1
  report > "$dir/report.txt" || return 1
  for t in run run_phase error reconciliation id_map code_map watermark checkpoint; do
    docker compose exec -T postgres psql -U demo -d shop -q -v ON_ERROR_STOP=1 \
      -c "COPY mig.$t TO STDOUT WITH (FORMAT csv, HEADER)" > "$dir/mig_$t.csv" || return 1
  done
  echo "audit trail archived in full-custom-migration/$dir"
}

# Based on the command, run the pipeline (or a part of it) via above functions.
case "$cmd" in
  # LEGACY_SOURCE: (re)create the OLD system (database legacy_shop) and fill it with its intentionally dirty data.
  # Resets the source to its original state, e.g. after a delta run changed it with legacy_changes.sql.
  source)
    # WITH (FORCE): PostgreSQL 13+, disconnects open sessions before dropping
    # We do not use ensure_legacy_source() because we need to drops it and recreates it in case that database already exists.
    sql postgres "DROP DATABASE IF EXISTS legacy_shop WITH (FORCE)"
    sql postgres "CREATE DATABASE legacy_shop"
    run_file legacy_shop source/legacy_shop.sql && echo "old system (legacy_shop) created" ;;
  # ASSESS: profile the old system BEFORE writing rules (00_assess/): volumes, formats, missing values,
  # duplicates, orphans, value lists. Read-only and not logged as a run: the output is the input for
  # the rules, the code maps and the planning.
  assess)
    run_setup     # needs the src foreign tables (00_setup/001)
    echo "==== 00_assess"
    for f in 00_assess/*.sql; do
      run_file shop "$f" || exit 1
    done ;;
  # ALL: the complete migration as one full run: setup, then every phase from extract to verify.
  # Stops at the first failing file or gate. Production is only touched if both earlier gates passed,
  # load refuses to start unless validate, transform and reconcile are DONE.
  all)
    # a new run (mig.run), then every phase in order; any failing file or gate stops it
    run_setup
    sql shop "SELECT mig.new_run('full')"
    for p in 01_extract 02_validate 03_transform 04_reconcile 05_load 06_verify; do
      run_phase "$p";
    done
    sql shop "SELECT mig.end_run('DONE')"
    echo "==== full run finished: all gates passed" ;;
  # SETUP: create both databases if missing and (re)run 00_setup (schemas, control tables, helper, functions, code maps, target schema).
  # Idempotent: re-run it after changing a helper or a mapping in 00_setup/.
  setup)
    run_setup ;;
  # EXTRACT | VALIDATE | TRANSFORM | RECONCILE | LOAD | VERIFY: re-run ONE phase within the current run,
  # e.g. after fixing a rule, then continue with the next phases (a failed phase can be retried like this).
  extract|validate|transform|reconcile|load|verify)
    # one phase again, within the CURRENT run
    run_phase "$(phase_dir "$cmd")" ;;
  # DELTA: simulate new user changes in old system after the initial fetching (source/legacy_changes.sql),
  # then sync only the changed rows into production in a new delta run, with all gates again.
  delta)
    # changes in the old system -> new delta run: incremental extract, then the same phases again
    echo "==== changes in the old system"
    run_file legacy_shop source/legacy_changes.sql || exit 1
    sql shop "SELECT mig.new_run('delta')"
    run_phase 07_delta_sync 07_cutover/710_delta_sync.sql
    for p in 02_validate 03_transform 04_reconcile 05_load 06_verify; do run_phase "$p"; done
    sql shop "SELECT mig.end_run('DONE')"
    echo "==== delta run finished: all gates passed" ;;
  # CUTOVER: the switch to the new system. Freeze the old system (read-only), one last delta with all
  # gates, a smoke test of the new system, then the go/no-go gate.
  # GO -> switch the application. NO-GO (or any failure on the way) -> ./run.sh unfreeze.
  cutover)
    sql shop "SELECT mig.new_run('cutover')" || exit 1
    run_phase 07_freeze_source 07_cutover/720_freeze_source.sql
    run_phase 07_delta_sync 07_cutover/710_delta_sync.sql
    for p in 02_validate 03_transform 04_reconcile 05_load 06_verify; do run_phase "$p"; done
    run_phase 07_smoke_test 07_cutover/760_smoke_test.sql
    run_phase 07_go_no_go 07_cutover/780_go_no_go.sql
    sql shop "SELECT mig.end_run('DONE')"
    echo "==== cutover finished: GO" ;;
  # UNFREEZE: the NO-GO path. The old system stays the live system and accepts writes again.
  unfreeze)
    run_file shop 07_cutover/729_unfreeze_source.sql ;;
  # REPORT: show the audit trail of the current run:
  # all runs, phase durations, findings per rule (rejects and warnings) and every check with expected/actual. Read-only.
  report)
    report ;;
  # ARCHIVE: save the report and every mig table as files (archive/<timestamp>/), e.g. for the project
  # documentation or an auditor. Also the first step of cleanup.
  archive)
    archive_reports || { echo ">>> ARCHIVE FAILED"; exit 1; } ;;
  # ROLLBACK: remove exactly the rows the migration loaded into production (via mig.id_map),
  # e.g. when verify fails and can't be fixed forward. Only safe before users write to the new system.
  rollback)
    run_file shop 07_cutover/790_rollback.sql ;;
  # CLEANUP: after go-live, archive the reports (as above), then drop the working layers (raw, stg, src)
  # and the connection to the old system; the mig schema stays as the audit trail.
  # Nothing is dropped if the archive fails.
  cleanup)
    archive_reports || { echo ">>> ARCHIVE FAILED: cleanup not started"; exit 1; }
    run_file shop 08_cleanup/810_drop_raw_stg.sql ;;
  # RESET: drop the NEW system (database shop) completely, to start over from scratch.
  # The old system (legacy_shop) is not touched.
  reset)
    sql postgres "DROP DATABASE IF EXISTS shop WITH (FORCE)" && echo "new system (shop) dropped" ;;
  # PSQL: open an interactive psql session to look around (database shop by default, or legacy_shop).
  psql)
    # interactive: exec WITHOUT -T, so psql gets a terminal
    docker compose exec postgres psql -U demo -d "${2:-shop}" ;;
  *)
    echo "Unknown command '$cmd'"; exit 1 ;;
esac

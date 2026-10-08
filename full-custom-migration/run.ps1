<#
Orchestrates the migration pipeline: runs the phase folders in order, one transaction per file,
records every phase in mig.run_phase, and STOPS at the first failed file or gate.

Usage: .\run.ps1 <command>
  source       (re)create the OLD system (database legacy_shop) with its intentionally dirty data
  assess       profile the old system (00_assess): volumes, formats, orphans, duplicates. Read-only
  all          full run: setup -> extract -> validate -> transform -> reconcile -> load -> verify
  setup        create both databases and run all 00_setup scripts (mig schema, tables, rules, ...)
  extract | validate | transform | reconcile | load | verify
               run ONE phase again within the current run (e.g. after fixing a rule)
  delta        change data in the old system, then incremental extract + validate .. verify
  cutover      freeze the old system, final delta + validate .. verify, smoke test, go/no-go gate
  unfreeze     NO-GO: make the old system writable again (07_cutover/729)
  report       findings, check results and phase history of the current run
  archive      save the report + every mig table as files in archive/<timestamp>/
  rollback     remove everything the migration loaded into production (07_cutover/790)
  cleanup      archive, then drop raw / stg / src after go-live, keep the mig audit trail (08_cleanup/810)
  reset        drop the NEW system (database shop) to start over; the old system stays
  psql [db]    interactive session (db: shop (default) | legacy_shop)
#>
param(
    # 1st parameter, required: the command
    [Parameter(Mandatory = $true)]
    [ValidateSet("source", "assess", "all", "setup", "extract", "validate", "transform", "reconcile", "load", "verify",
                 "delta", "cutover", "unfreeze", "report", "archive", "rollback", "cleanup", "reset", "psql")]
    [string]$Command,
    # 2nd parameter, only for psql: the database (not "-Db": that collides with the built-in -Debug alias)
    [string]$Database = "shop"
)
$ErrorActionPreference = "Continue"   # native tools (docker) report errors via $LASTEXITCODE; failures are handled explicitly
Set-Location $PSScriptRoot            # (bash: cd "$(dirname "$0")")

# Make sure the database container is running and ready before any script touches it.
#   docker compose   │ Works with the services defined in docker-compose.yml in the current folder
#   --progress quiet │ Hides the progress output
#   up               │ Creates and starts the service; does nothing if it's already running
#   -d               │ Detached mode (run in background)
#   --wait           │ Waits until the container is healthy before returning, using the healthcheck from the compose file
#   postgres         │ The only service: one PostgreSQL with both databases (legacy_shop = old, shop = new)
docker compose --progress quiet up -d --wait postgres
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Run one SQL file. One transaction per file (-1), except *_batched*.sql: those COMMIT themselves.
# Returns $true on success.
#   Params:
#     $database,
#     $file sql script file (relative to full-custom-migration/, mounted in the container as /migration)
#   exec -T            │ Runs psql in the running container, no pseudo-terminal (output can be piped/filtered)
#   psql -U -d         │ user and database
#   -q                 │ quiet: no "INSERT 0 1"-style status messages (results, \echo and NOTICEs still shown)
#   -v ON_ERROR_STOP=1 │ stop at the first error with a non-zero exit code (a failed gate stops the pipeline)
#   -1                 │ run the whole file as ONE transaction: an error leaves nothing half-done
#   -f                 │ the file to run (path inside the container)
#   $psqlArgs          │ arguments built as an array, so "-1" can be left out (not "$args": that's a built-in variable)
#   | Out-Host         │ show psql's output on the console instead of returning it, so the function returns only the boolean
function Invoke-SqlFile([string]$database, [string]$file) {
    Write-Host "---- $file"
    $psqlArgs = @("compose", "exec", "-T", "postgres", "psql", "-U", "demo", "-d", $database, "-q", "-v", "ON_ERROR_STOP=1")
    if ($file -notlike "*_batched*") { $psqlArgs += "-1" }
    $psqlArgs += @("-f", "/migration/$file")
    & docker @psqlArgs | Out-Host
    return ($LASTEXITCODE -eq 0)
}

# Run one bookkeeping SQL statement (mig.phase_start, CREATE DATABASE, ...). Returns $true on success.
#   Params:
#     $database,
#     $statement to run
#   -qtA               │ quiet, tuples only (no headers), unaligned: bare values
#   -c                 │ the statement to run
#   | Out-Null         │ output suppressed; only the exit code matters (bash: >/dev/null)
function Invoke-Sql([string]$database, [string]$statement) {
    docker compose exec -T postgres psql -U demo -d $database -qtA -v ON_ERROR_STOP=1 -c $statement | Out-Null
    return ($LASTEXITCODE -eq 0)
}

# Does database $name exist? (queried from the maintenance database "postgres")
#   -tAc               │ tuples only, unaligned, run the statement: prints just "1" or nothing
function Test-Db([string]$name) {
    $r = docker compose exec -T postgres psql -U demo -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$name'"
    return ("$r".Trim() -eq "1")
}

# Create the OLD system on first use (the source/legacy_shop.sql script fills it with intentionally dirty data)
function Initialize-LegacySource {
    if (-not (Test-Db "legacy_shop")) {
        if (Invoke-Sql postgres "CREATE DATABASE legacy_shop") { Invoke-SqlFile legacy_shop "source/legacy_shop.sql" | Out-Null }
    }
}

# Create the NEW system's empty database on first use
function Initialize-Shop {
    if (-not (Test-Db "shop")) { Invoke-Sql postgres "CREATE DATABASE shop" | Out-Null }
}

# Setup: both databases + every 00_setup script (all idempotent, safe to re-run). Not logged in
# mig.run_phase: the mig schema itself is created here.
function Initialize-Setup {
    Initialize-LegacySource; Initialize-Shop
    Write-Host "==== 00_setup"
    foreach ($f in Get-ChildItem "00_setup/*.sql" | Sort-Object Name) {
        if (-not (Invoke-SqlFile shop "00_setup/$($f.Name)")) { Write-Host ">>> SETUP FAILED"; exit 1 }
    }
}

# Run all files of a phase folder (or the given files) and record the outcome in mig.run_phase.
#   Params:
#     $phase name,
#     $files (default: all *.sql in the folder named like the phase, in name order)
#   mig.phase_start    │ phase RUNNING (re-opens a FAILED run when a phase is retried)
#   mig.phase_end      │ DONE, or FAILED at the first failing file -> the pipeline stops (exit 1)
function Invoke-Phase([string]$phase, [string[]]$files) {
    if (-not $files) { $files = @(Get-ChildItem "$phase/*.sql" | Sort-Object Name | ForEach-Object { "$phase/$($_.Name)" }) }
    Write-Host "==== $phase"
    if (-not (Invoke-Sql shop "SELECT mig.phase_start('$phase')")) { exit 1 }
    foreach ($f in $files) {
        if (-not (Invoke-SqlFile shop $f)) {
            Invoke-Sql shop "SELECT mig.phase_end('$phase', 'FAILED')" | Out-Null
            Write-Host ">>> PHASE $phase FAILED in $f. The pipeline stops here (see .\run.ps1 report)."
            exit 1
        }
    }
    Invoke-Sql shop "SELECT mig.phase_end('$phase', 'DONE')" | Out-Null
}

# Mapping: command name -> phase folder
$phaseDirs = @{ extract = "01_extract"; validate = "02_validate"; transform = "03_transform";
                reconcile = "04_reconcile"; load = "05_load"; verify = "06_verify" }

# The report: all runs, phase durations, findings per rule and every check of the current run. Read-only.
# Used by "report" (to the screen) and "archive" (to a file). Returns psql's output as text.
#   @' ... '@          │ single-quoted here-string piped to psql's stdin (bash: here-document <<'SQL'); nothing is expanded
function Get-Report {
    @'
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
'@ | docker compose exec -T postgres psql -U demo -d shop -q
}

# Archive the audit trail OUTSIDE the database (part of 8 CLEANUP): the report as text, and every mig
# table as CSV, in archive/<timestamp>/ next to this script. Returns $true on success.
#   COPY ... TO STDOUT │ the server streams the table to psql; PowerShell writes it into a file on the host
#   FORMAT csv, HEADER │ one CSV file per table, with column names
#   Out-File -Encoding utf8 │ (bash: > file)
function Save-Archive {
    $dir = "archive/" + (Get-Date -Format "yyyyMMdd-HHmmss")
    New-Item -ItemType Directory -Force $dir | Out-Null
    Get-Report | Out-File -Encoding utf8 "$dir/report.txt"
    if ($LASTEXITCODE -ne 0) { return $false }
    foreach ($t in "run", "run_phase", "error", "reconciliation", "id_map", "code_map", "watermark", "checkpoint") {
        docker compose exec -T postgres psql -U demo -d shop -q -v ON_ERROR_STOP=1 `
            -c "COPY mig.$t TO STDOUT WITH (FORMAT csv, HEADER)" | Out-File -Encoding utf8 "$dir/mig_$t.csv"
        if ($LASTEXITCODE -ne 0) { return $false }
    }
    Write-Host "audit trail archived in full-custom-migration/$dir"
    return $true
}

# Based on the command, run the pipeline (or a part of it) via above functions.
switch ($Command) {
    # LEGACY_SOURCE: (re)create the OLD system (database legacy_shop) and fill it with its intentionally dirty data.
    # Resets the source to its original state, e.g. after a delta run changed it with legacy_changes.sql.
    "source" {
        # WITH (FORCE): PostgreSQL 13+, disconnects open sessions before dropping
        # We do not use Initialize-LegacySource because it must drop and recreate the database even if it already exists.
        Invoke-Sql postgres "DROP DATABASE IF EXISTS legacy_shop WITH (FORCE)" | Out-Null
        Invoke-Sql postgres "CREATE DATABASE legacy_shop" | Out-Null
        if (Invoke-SqlFile legacy_shop "source/legacy_shop.sql") { Write-Host "old system (legacy_shop) created" }
    }
    # ASSESS: profile the old system BEFORE writing rules (00_assess/): volumes, formats, missing values,
    # duplicates, orphans, value lists. Read-only and not logged as a run: the output is the input for
    # the rules, the code maps and the planning.
    "assess" {
        Initialize-Setup     # needs the src foreign tables (00_setup/001)
        Write-Host "==== 00_assess"
        foreach ($f in Get-ChildItem "00_assess/*.sql" | Sort-Object Name) {
            if (-not (Invoke-SqlFile shop "00_assess/$($f.Name)")) { exit 1 }
        }
    }
    # ALL: the complete migration as one full run: setup, then every phase from extract to verify.
    # Stops at the first failing file or gate. Production is only touched if both earlier gates passed,
    # load refuses to start unless validate, transform and reconcile are DONE.
    "all" {
        # a new run (mig.run), then every phase in order; any failing file or gate stops it
        Initialize-Setup
        Invoke-Sql shop "SELECT mig.new_run('full')" | Out-Null
        foreach ($p in "01_extract", "02_validate", "03_transform", "04_reconcile", "05_load", "06_verify") {
            Invoke-Phase $p
        }
        Invoke-Sql shop "SELECT mig.end_run('DONE')" | Out-Null
        Write-Host "==== full run finished: all gates passed"
    }
    # SETUP: create both databases if missing and (re)run 00_setup (schemas, control tables, helper, functions, code maps, target schema).
    # Idempotent: re-run it after changing a helper or a mapping in 00_setup/.
    "setup" { Initialize-Setup }
    # EXTRACT | VALIDATE | TRANSFORM | RECONCILE | LOAD | VERIFY: re-run ONE phase within the current run,
    # e.g. after fixing a rule, then continue with the next phases (a failed phase can be retried like this).
    { $phaseDirs.ContainsKey($_) } {
        # one phase again, within the CURRENT run
        Invoke-Phase $phaseDirs[$Command]
    }
    # DELTA: simulate new user changes in old system after the initial fetching (source/legacy_changes.sql),
    # then sync only the changed rows into production in a new delta run, with all gates again.
    "delta" {
        # changes in the old system -> new delta run: incremental extract, then the same phases again
        Write-Host "==== changes in the old system"
        if (-not (Invoke-SqlFile legacy_shop "source/legacy_changes.sql")) { exit 1 }
        Invoke-Sql shop "SELECT mig.new_run('delta')" | Out-Null
        Invoke-Phase "07_delta_sync" @("07_cutover/710_delta_sync.sql")
        foreach ($p in "02_validate", "03_transform", "04_reconcile", "05_load", "06_verify") { Invoke-Phase $p }
        Invoke-Sql shop "SELECT mig.end_run('DONE')" | Out-Null
        Write-Host "==== delta run finished: all gates passed"
    }
    # CUTOVER: the switch to the new system. Freeze the old system (read-only), one last delta with all
    # gates, a smoke test of the new system, then the go/no-go gate.
    # GO -> switch the application. NO-GO (or any failure on the way) -> .\run.ps1 unfreeze.
    "cutover" {
        if (-not (Invoke-Sql shop "SELECT mig.new_run('cutover')")) { exit 1 }
        Invoke-Phase "07_freeze_source" @("07_cutover/720_freeze_source.sql")
        Invoke-Phase "07_delta_sync" @("07_cutover/710_delta_sync.sql")
        foreach ($p in "02_validate", "03_transform", "04_reconcile", "05_load", "06_verify") { Invoke-Phase $p }
        Invoke-Phase "07_smoke_test" @("07_cutover/760_smoke_test.sql")
        Invoke-Phase "07_go_no_go" @("07_cutover/780_go_no_go.sql")
        Invoke-Sql shop "SELECT mig.end_run('DONE')" | Out-Null
        Write-Host "==== cutover finished: GO"
    }
    # UNFREEZE: the NO-GO path. The old system stays the live system and accepts writes again.
    "unfreeze" { Invoke-SqlFile shop "07_cutover/729_unfreeze_source.sql" | Out-Null }
    # REPORT: show the audit trail of the current run:
    # all runs, phase durations, findings per rule (rejects and warnings) and every check with expected/actual. Read-only.
    "report" { Get-Report | Out-Host }
    # ARCHIVE: save the report and every mig table as files (archive/<timestamp>/), e.g. for the project
    # documentation or an auditor. Also the first step of cleanup.
    "archive" {
        if (-not (Save-Archive)) { Write-Host ">>> ARCHIVE FAILED"; exit 1 }
    }
    # ROLLBACK: remove exactly the rows the migration loaded into production (via mig.id_map),
    # e.g. when verify fails and can't be fixed forward. Only safe before users write to the new system.
    "rollback" { Invoke-SqlFile shop "07_cutover/790_rollback.sql" | Out-Null }
    # CLEANUP: after go-live, archive the reports (as above), then drop the working layers (raw, stg, src)
    # and the connection to the old system; the mig schema stays as the audit trail.
    # Nothing is dropped if the archive fails.
    "cleanup" {
        if (-not (Save-Archive)) { Write-Host ">>> ARCHIVE FAILED: cleanup not started"; exit 1 }
        Invoke-SqlFile shop "08_cleanup/810_drop_raw_stg.sql" | Out-Null
    }
    # RESET: drop the NEW system (database shop) completely, to start over from scratch.
    # The old system (legacy_shop) is not touched.
    "reset" {
        if (Invoke-Sql postgres "DROP DATABASE IF EXISTS shop WITH (FORCE)") { Write-Host "new system (shop) dropped" }
    }
    # PSQL: open an interactive psql session to look around (database shop by default, or legacy_shop).
    "psql" {
        # interactive: exec WITHOUT -T, so psql gets a terminal
        docker compose exec postgres psql -U demo -d $Database
    }
}

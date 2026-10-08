<#
Runs one Flyway scenario in its own PostgreSQL schema (schema name = lowercase scenario ID).

Usage: .\run.ps1 <ID> [action] [arg]
  migrate [version]   apply migrations (optionally only up to <version>)
  info | validate     Flyway info / validate
  repair              remove failed entries from the history (after a failed non-transactional migration)
  clean               drop everything in the scenario schema
  verify              run verify.sql
  sql <file>          run a scenario file with psql (app_v1.sql, demo_*.sql, ...)
  psql                interactive psql session with search_path set to the scenario schema
  all                 clean + migrate + verify
Env:  $env:LOCATIONS = "a,b"     migration folders inside the scenario, comma-separated (default: migrations)
      $env:FLYWAY_ARGS = "opts"  extra Flyway options, e.g. -outOfOrder=true

Examples: .\run.ps1 B1 migrate 2 | .\run.ps1 B1 sql app_v1.sql | .\run.ps1 D2 all
          $env:LOCATIONS = "migrations,late"; $env:FLYWAY_ARGS = "-outOfOrder=true"; .\run.ps1 C1 migrate
#>
param(
    # 1st parameter, required: scenario ID (e.g. B1, D2, ...)
    [Parameter(Mandatory = $true)][string]$Id,
    # 2nd parameter, defaults to "migrate"
    [string]$Action = "migrate",
    # 3rd parameter, optional: target version for migrate, or the file name for sql
    [string]$Arg
)
$ErrorActionPreference = "Continue"   # native tools (docker) report errors via $LASTEXITCODE
Set-Location $PSScriptRoot            # (bash: cd "$(dirname "$0")")

# Derived parameters
$Id = $Id.ToUpper()
$dir = Get-ChildItem -Directory "scenarios" | Where-Object { $_.Name -like "$Id-*" } | Select-Object -First 1
if (-not $dir) {
    Write-Host "Unknown scenario '$Id'. Available:"
    Get-ChildItem -Directory "scenarios" | ForEach-Object { $_.Name }
    exit 1
}
$name = $dir.Name
$schema = $Id.ToLower()
# Migration folders ($env:LOCATIONS, default "migrations") -> filesystem:/scenarios/<name>/<folder>,...
$folders = if ($env:LOCATIONS) { $env:LOCATIONS } else { "migrations" }
$locations = ($folders -split "," | ForEach-Object { "filesystem:/scenarios/$name/$($_.Trim())" }) -join ","
# Extra Flyway options ($env:FLYWAY_ARGS), split into words (bash: unquoted ${FLYWAY_ARGS:-})
$extraArgs = @(if ($env:FLYWAY_ARGS) { $env:FLYWAY_ARGS -split "\s+" | Where-Object { $_ } })

# Make sure the database container is running and ready before any script touches it.
#   docker compose   │ Works with the services defined in docker-compose.yml in the current folder
#   --progress quiet │ Hides the progress output
#   up               │ Creates and starts the service; does nothing if it's already running
#   -d               │ Detached mode (run in background)
#   --wait           │ Waits until the container is healthy before returning, using the healthcheck from the compose file
#   postgres         │ Only this service.
docker compose --progress quiet up -d --wait postgres
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

function Invoke-Flyway([string[]]$FlywayArgs) {
    #   run             │ Starts a new one-off container of the service and runs a command in it.
    #   --rm            │ Removes the container as soon as it finishes
    #   -T              │ No pseudo-terminal, so the output can be piped and filtered (scripts, CI).
    #   flyway          │ The service from the compose file (image, mounted scenarios, connection settings).
    #   -schemas        │ The PostgreSQL schema Flyway manages: It creates it if missing, keeps flyway_schema_history in it, and uses it as the default schema (search_path) while migrating.
    #                     This is what isolates the scenarios from each other
    #   -locations      │ Where the migration scripts are, inside the container (one or more folders)
    #   @extraArgs      │ Extra options from $env:FLYWAY_ARGS
    #   @FlywayArgs     │ Everything else passed to the function: the Flyway command and extra options (bash: "$@")
    docker compose --progress quiet run --rm -T flyway `
        "-schemas=$schema" `
        "-locations=$locations" `
        @extraArgs `
        @FlywayArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Invoke-PsqlFile([string]$File) {
    #   exec            │ Runs a command in an already running container.
    #   -T              │ No pseudo-terminal, so the output can be piped and filtered (scripts, CI).
    #   -e PGOPTIONS    │ Sets an environment variable for this one command: search_path = scenario schema.
    #   postgres        │ The service/container to execute in.
    #   psql            │ The command to run inside the container.
    #   -U -d           │ psql: user and database
    #   -q              │ quiet: no "INSERT 0 1"-style status messages (results and NOTICEs still shown)
    #   -v ON_ERROR_STOP=1 │ stop at the first error with a non-zero exit code
    #   -f              │ the file to run (path inside the container, where ./scenarios is mounted)
    docker compose exec -T -e "PGOPTIONS=-c search_path=$schema" postgres `
        psql -U demo -d demo -q -v ON_ERROR_STOP=1 -f "/scenarios/$name/$File"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# Based on the action, run the corresponding Flyway command or psql command, via above functions.
Write-Host "== $name (schema: $schema) -> $Action"
switch ($Action) {
    "migrate" {
        # 3rd parameter is an optional target version for migrate (e.g. 2, 3, ...)
        if ($Arg) { Invoke-Flyway @("-target=$Arg", "migrate") } else { Invoke-Flyway @("migrate") }
        break
    }
    { $_ -in @("info", "validate", "clean", "repair") } { Invoke-Flyway @($Action); break }
    "verify" { Invoke-PsqlFile "verify.sql"; break }
    "sql" {
        # 3rd parameter is an optional file name to run with psql (e.g. app_v1.sql, demo_*.sql, ...)
        if (-not $Arg) { Write-Host "usage: .\run.ps1 $Id sql <file>"; exit 1 }
        Invoke-PsqlFile $Arg
        break
    }
    "psql" { docker compose exec -e "PGOPTIONS=-c search_path=$schema" postgres psql -U demo -d demo; break }
    "all" {
        Invoke-Flyway @("clean")
        Invoke-Flyway @("migrate")
        Invoke-PsqlFile "verify.sql"
        break
    }
    default { Write-Host "Unknown action '$Action'"; exit 1 }
}

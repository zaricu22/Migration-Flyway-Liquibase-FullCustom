<#
Runs one Liquibase scenario against PostgreSQL, MySQL and/or MSSQL.
Each run starts from an EMPTY database per engine (named after the scenario, e.g. l1).

Usage: .\run.ps1 <ID> [engine] [format] [mode]
  engine: all (default) | postgres | mysql | mssql
  format: yaml (default) | xml
  mode:   update  (default) reset database, liquibase update, inspect the result
          rerun   liquibase update WITHOUT resetting the database first, then inspect
          sql     print the SQL that Liquibase would generate (update-sql), change nothing
          inspect only run the inspect scripts
          <other> any other Liquibase command (rollback, rollback-count, tag, history, status, ...),
                  run WITHOUT resetting the database first, then inspect
Env:    $env:CHANGELOG = "<name>"   changelog file name without extension (default: changelog)
        $env:LB_ARGS = "<options>"  extra Liquibase options, e.g. --context-filter=dev or --tag=v1

Examples: .\run.ps1 L1 | .\run.ps1 L14 mysql xml | .\run.ps1 L8 mssql yaml sql
          $env:LB_ARGS = "--tag=v1"; .\run.ps1 L22 postgres yaml rollback
#>
param(
    # 1st parameter, required: scenario ID (e.g. L1, L14, ...)
    [Parameter(Mandatory = $true)][string]$Id,
    # 2nd parameter, defaults to "all" engines
    [ValidateSet("all", "postgres", "mysql", "mssql")][string]$Engine = "all",
    # 3rd parameter, defaults to "yaml" changelog format
    [ValidateSet("yaml", "xml")][string]$Format = "yaml",
    # 4th parameter, defaults to "update" mode (update | rerun | sql | inspect | any other Liquibase command)
    [string]$Mode = "update"
)
$ErrorActionPreference = "Continue"   # native tools (docker) report errors via $LASTEXITCODE; a failed update must not stop the script
Set-Location $PSScriptRoot            # (bash: cd "$(dirname "$0")")

# Same password for all engines (see docker-compose.yml)
$PW = "Demo_Pass123"
$Id = $Id.ToUpper()
# Changelog file: name from the CHANGELOG env variable (default "changelog") + format extension
$changelogName = if ($env:CHANGELOG) { $env:CHANGELOG } else { "changelog" }
$changelog = "$changelogName.$Format"
# Extra Liquibase options ($env:LB_ARGS), split into words (bash: unquoted ${LB_ARGS:-})
$lbArgs = @(if ($env:LB_ARGS) { $env:LB_ARGS -split "\s+" | Where-Object { $_ } })

# Derived parameters
$dir = Get-ChildItem -Directory "scenarios" | Where-Object { $_.Name -like "$Id-*" } | Select-Object -First 1
if (-not $dir) {
    Write-Host "Unknown scenario '$Id'. Available:"
    Get-ChildItem -Directory "scenarios" | ForEach-Object { $_.Name }
    exit 1
}
$name = $dir.Name
$db = $Id.ToLower()                   # database name per engine = lowercase scenario ID
if (-not (Test-Path (Join-Path $dir.FullName $changelog))) { Write-Host "Missing $name/$changelog"; exit 1 }

# Engines that this run needs (e.g. "postgres mysql mssql" or just "mysql").
# The engine names must match the service names in docker-compose.yml.
# @( ... ) keeps a single engine an ARRAY (otherwise PowerShell unrolls it to a string, and
# splatting a string passes its characters: "no such service: m")
$engines = @(if ($Engine -eq "all") { "postgres", "mysql", "mssql" } else { $Engine })

# Make sure the needed database containers are running and ready before any script touches them.
#   docker compose   │ Works with the services defined in docker-compose.yml in the current folder
#   --progress quiet │ Hides the progress output
#   up               │ Creates and starts the services; does nothing for services already running
#   -d               │ Detached mode (run in background)
#   --wait           │ Waits until the containers are healthy (SQL Server takes the longest)
#   @engines         │ Only the engines containers that this run needs (bash: $engines)
docker compose --progress quiet up -d --wait @engines
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# The official Liquibase image bundles the PostgreSQL and SQL Server JDBC drivers, but not the MySQL driver.
# Build the Liquibase image with the MySQL JDBC driver (only the first time; later it's cached).
#   build liquibase  │ Builds the image from the dockerfile_inline in docker-compose.yml
docker compose --progress quiet build liquibase | Out-Null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# JDBC connection URL per engine. Host names = service names on the compose network. (Liquibase command parameter)
#   mysql: allowPublicKeyRetrieval / useSSL=false   │ allow password login without TLS (local demo only)
#   mssql: encrypt=true;trustServerCertificate=true │ encrypted, but accept the container's self-signed certificate
#   ${db}? : braces needed, otherwise PowerShell would read "$db?" as a variable named "db?"
function Get-JdbcUrl([string]$e) {
    switch ($e) {
        "postgres" { "jdbc:postgresql://postgres:5432/$db" }
        "mysql"    { "jdbc:mysql://mysql:3306/${db}?allowPublicKeyRetrieval=true&useSSL=false" }
        "mssql"    { "jdbc:sqlserver://mssql:1433;databaseName=$db;encrypt=true;trustServerCertificate=true" }
    }
}

# Database user per engine (Liquibase command parameter)
function Get-DbUser([string]$e) {
    switch ($e) { "postgres" { "demo" } "mysql" { "root" } "mssql" { "sa" } }
}

# Run one Liquibase command against one engine. Returns $true on success:
#   $e engine,
#   $command (update | update-sql | rollback | tag | ...)
#   run                     │ Starts a new one-off container of the service and runs a command in it.
#   --rm                    │ Removes the container as soon as it finishes
#   -T                      │ No pseudo-terminal, so the output can be piped and filtered (scripts, CI).
#   liquibase               │ The service from the compose file (image with MySQL driver, mounted scenarios).
#   --search-path           │ Folder where Liquibase looks for the changelog (and files it references, e.g. CSV)
#   --changelog-file        │ Changelog relative to the search path; this name is stored in DATABASECHANGELOG
#   --url                   │ JDBC URL of the engine and the scenario's database
#   --username / --password │ Database credentials
#   $command                │ The Liquibase command (bash: "$2")
#   @lbArgs                 │ Extra options from $env:LB_ARGS
#   | Out-Host              │ show Liquibase's output on the console instead of returning it, so the function returns only the boolean
function Invoke-Liquibase([string]$e, [string]$command) {
    docker compose --progress quiet run --rm -T liquibase `
        "--search-path=/scenarios/$name" `
        "--changelog-file=$changelog" `
        "--url=$(Get-JdbcUrl $e)" `
        "--username=$(Get-DbUser $e)" `
        "--password=$PW" `
        $command `
        @lbArgs | Out-Host
    return ($LASTEXITCODE -eq 0)
}

# Run an inspect SQL file with the engine's own client: (Invoke-Inspect function only)
#   $e engine
#   $path file path inside the container
# (./scenarios and ./common are mounted into the database containers as /scenarios and /common).
#   psql -f                            │ run the file (errors are shown, the script continues: no ON_ERROR_STOP)
#   sh -c "mysql ... < file"           │ the mysql client reads the file from stdin inside the container
#   --default-character-set=utf8mb4    │ show Unicode correctly (otherwise the client displays '?')
#   --table                            │ table-formatted output, like psql
#   --force                            │ continue after an error (inspect scripts contain intended failures)
#   sqlcmd -d -i                       │ database, input file
#   sqlcmd -W -s "|"                   │ trim trailing spaces, "|" as column separator (-s takes ONE character)
function Invoke-SqlFile([string]$e, [string]$path) {
    switch ($e) {
        "postgres" { docker compose exec -T postgres psql -q -U demo -d $db -f $path }
        "mysql"    { docker compose exec -T -e "MYSQL_PWD=$PW" mysql sh -c "mysql -uroot --default-character-set=utf8mb4 --table --force $db < $path" }
        "mssql"    { docker compose exec -T mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P $PW -d $db -W -s "|" -i $path }
    }
}

# Show what Liquibase really created: the common column report, then the scenario's own checks (if any).
function Invoke-Inspect([string]$e) {
    Write-Host "--- columns"
    # See columns types created by Liquibase on the chosen engine
    Invoke-SqlFile $e "/common/inspect-$e.sql"
    if (Test-Path (Join-Path $dir.FullName "inspect/$e.sql")) {
        Write-Host "--- scenario checks"
        # See specific checks for this scenario and engine (if any)
        Invoke-SqlFile $e "/scenarios/$name/inspect/$e.sql"
    }
}

# Drop and recreate the scenario's database, so every run starts empty. Returns $true on success.
#   exec -T                        │ Runs the engine's own client inside its running container, no pseudo-terminal
#   psql -q -U -d postgres -c      │ quiet, user, connect to the maintenance db "postgres", run a statement
#   WITH (FORCE)                   │ PostgreSQL 13+: disconnects open sessions before dropping
#   -e MYSQL_PWD                   │ password via environment (avoids the "password on command line" warning)
#   mysql -uroot -e                │ user root, run statements
#   sqlcmd -C                      │ trust the server certificate (self-signed)
#   sqlcmd -b                      │ exit with an error code if a statement fails
#   sqlcmd -S -U -P -Q             │ server, user, password, run the query and exit
#   SET SINGLE_USER ... IMMEDIATE  │ SQL Server: rolls back and disconnects open sessions before dropping
#   | Out-Null                     │ discard the output, so the function returns only the boolean
function Reset-Db([string]$e) {
    switch ($e) {
        "postgres" {
            docker compose exec -T postgres psql -q -U demo -d postgres `
                -c "DROP DATABASE IF EXISTS $db WITH (FORCE)" -c "CREATE DATABASE $db" | Out-Null
        }
        "mysql" {
            docker compose exec -T -e "MYSQL_PWD=$PW" mysql mysql -uroot `
                -e "DROP DATABASE IF EXISTS $db; CREATE DATABASE $db" | Out-Null
        }
        "mssql" {
            docker compose exec -T mssql /opt/mssql-tools18/bin/sqlcmd -C -b -S localhost -U sa -P $PW `
                -Q "IF DB_ID('$db') IS NOT NULL BEGIN ALTER DATABASE $db SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE $db; END; CREATE DATABASE $db" | Out-Null
        }
    }
    return ($LASTEXITCODE -eq 0)
}

# For every selected engine, run the mode via above functions (Reset-Db -> Invoke-Liquibase -> Invoke-Inspect).
foreach ($e in $engines) {
    Write-Host ""
    Write-Host "=================== $name | $e | $changelog | $Mode ==================="
    switch ($Mode) {
        "update" {
            if (-not (Reset-Db $e)) { Write-Host "database reset failed"; continue }
            if (-not (Invoke-Liquibase $e "update")) { Write-Host ">>> liquibase update FAILED on $e (inspecting what was left behind)" }
            Invoke-Inspect $e
        }
        "rerun" {
            if (-not (Invoke-Liquibase $e "update")) { Write-Host ">>> liquibase update FAILED on $e (inspecting what was left behind)" }
            Invoke-Inspect $e
        }
        "sql" {
            if (-not (Reset-Db $e)) { Write-Host "database reset failed"; continue }
            Invoke-Liquibase $e "update-sql" | Out-Null   # the SQL itself goes to the console via Out-Host
        }
        "inspect" { Invoke-Inspect $e }
        default {
            # any other Liquibase command (rollback, tag, history, ...) on the existing database
            if (-not (Invoke-Liquibase $e $Mode)) { Write-Host ">>> liquibase $Mode FAILED on $e" }
            Invoke-Inspect $e
        }
    }
}

#!/usr/bin/env bash
# Runs one Liquibase scenario against PostgreSQL, MySQL and/or MSSQL.
# Each run starts from an EMPTY database per engine (named after the scenario, e.g. l1).
#
# Usage: ./run.sh <ID> [engine] [format] [mode]
#   engine: all (default) | postgres | mysql | mssql
#   format: yaml (default) | xml - changelog format
#   mode:   update  (default) reset database, liquibase update, inspect the result
#           rerun   liquibase update WITHOUT resetting the database first, then inspect
#           sql     print the SQL that Liquibase would generate (update-sql), change nothing
#           inspect only run the inspect scripts
#           <other> any other Liquibase command (rollback, rollback-count, tag, history, status, ...),
#                   run WITHOUT resetting the database first, then inspect
# Env:    CHANGELOG=<name>   changelog file name without extension (default: changelog)
#         LB_ARGS=<options>  extra Liquibase options, e.g. --context-filter=dev or --tag=v1
#
# Examples: ./run.sh L1 | ./run.sh L14 mysql xml | ./run.sh L8 mssql yaml sql
#           LB_ARGS=--tag=v1 ./run.sh L22 postgres yaml rollback
set -uo pipefail            # no -e: a failed update must not stop the script, it still inspects the result
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: don't rewrite /scenarios/... into C:/...
cd "$(dirname "$0")"

# Same password for all engines (see docker-compose.yml)
PW=Demo_Pass123
# 1st parameter, required: scenario ID (e.g. L1, L14, ...)
id=$(echo "${1:?usage: ./run.sh <ID> [all|postgres|mysql|mssql] [yaml|xml] [update|rerun|sql|inspect|<liquibase command>]}" | tr '[:lower:]' '[:upper:]')
# 2nd parameter, defaults to "all" engines
engine="${2:-all}"
# 3rd parameter, defaults to "yaml" changelog format
format="${3:-yaml}"
# 4th parameter, defaults to "update" mode
mode="${4:-update}"
# Changelog file: name from the CHANGELOG env variable (default "changelog") + format extension
changelog="${CHANGELOG:-changelog}.$format"

# Derived parameters
dir=$(ls -d scenarios/"$id"-* 2>/dev/null | head -n 1 || true)
[ -n "$dir" ] || { echo "Unknown scenario '$id'. Available:"; ls scenarios; exit 1; }
name=$(basename "$dir")
db=$(echo "$id" | tr '[:upper:]' '[:lower:]')          # database name per engine = lowercase scenario ID
[ -f "$dir/$changelog" ] || { echo "Missing $dir/$changelog"; exit 1; }

# Engines that this run needs (e.g. "postgres mysql mssql" or just "mysql").
# The engine names must match the service names in docker-compose.yml.
case "$engine" in
  all) engines="postgres mysql mssql" ;;
  postgres|mysql|mssql) engines="$engine" ;;
  *) echo "Unknown engine '$engine'"; exit 1 ;;
esac

# Make sure the needed database containers are running and ready before any script touches them.
#   docker compose   │ Works with the services defined in docker-compose.yml in the current folder
#   --progress quiet │ Hides the progress output
#   up               │ Creates and starts the services; does nothing for services already running
#   -d               │ Detached mode (run in background)
#   --wait           │ Waits until the containers are healthy (SQL Server takes the longest)
#   $engines         │ Only the engines containers that this run needs (e.g. "postgres mysql mssql")
docker compose --progress quiet up -d --wait $engines || exit 1

# The official Liquibase image bundles the PostgreSQL and SQL Server JDBC drivers, but not the MySQL driver.
# Build the Liquibase image with the MySQL JDBC driver (only the first time; later it's cached).
#   build liquibase  │ Builds the image from the dockerfile_inline in docker-compose.yml
docker compose --progress quiet build liquibase >/dev/null || exit 1

# JDBC connection URL per engine. Host names = service names on the compose network. (Liquibase command parameter)
#   mysql: allowPublicKeyRetrieval / useSSL=false   │ allow password login without TLS (local demo only)
#   mssql: encrypt=true;trustServerCertificate=true │ encrypted, but accept the container's self-signed certificate
jdbc_url() {
  case "$1" in
    postgres) echo "jdbc:postgresql://postgres:5432/$db" ;;
    mysql)    echo "jdbc:mysql://mysql:3306/$db?allowPublicKeyRetrieval=true&useSSL=false" ;;
    mssql)    echo "jdbc:sqlserver://mssql:1433;databaseName=$db;encrypt=true;trustServerCertificate=true" ;;
  esac
}

# Database user per engine (Liquibase command parameter)
db_user() { case "$1" in postgres) echo demo ;; mysql) echo root ;; mssql) echo sa ;; esac; }

# Run one Liquibase command against one engine:
#   $1 engine,
#   $2 command (update | update-sql | rollback | tag | ...)
#   run                     │ Starts a new one-off container of the service and runs a command in it.
#   --rm                    │ Removes the container as soon as it finishes
#   -T                      │ No pseudo-terminal, so the output can be piped and filtered (scripts, CI).
#   liquibase               │ The service from the compose file (image with MySQL driver, mounted scenarios).
#   --search-path           │ Folder where Liquibase looks for the changelog (and files it references, e.g. CSV)
#   --changelog-file        │ Changelog relative to the search path; this name is stored in DATABASECHANGELOG
#   --url                   │ JDBC URL of the engine and the scenario's database
#   --username / --password │ Database credentials
#   "$2"                    │ The Liquibase command
#   $LB_ARGS                │ Extra options from the environment (unquoted on purpose: split into words)
liquibase() {
  docker compose --progress quiet run --rm -T liquibase \
    --search-path="/scenarios/$name" \
    --changelog-file="$changelog" \
    --url="$(jdbc_url "$1")" \
    --username="$(db_user "$1")" \
    --password="$PW" \
    "$2" \
    ${LB_ARGS:-}
}

# Run an inspect SQL file with the engine's own client: (Inspect function only)
#   $1 engine
#   $2 file path inside the container
# (./scenarios and ./common are mounted into the database containers as /scenarios and /common).
#   psql -f                            │ run the file (errors are shown, the script continues: no ON_ERROR_STOP)
#   sh -c "mysql ... < file"           │ the mysql client reads the file from stdin inside the container
#   --default-character-set=utf8mb4    │ show Unicode correctly (otherwise the client displays '?')
#   --table                            │ table-formatted output, like psql
#   --force                            │ continue after an error (inspect scripts contain intended failures)
#   sqlcmd -d -i                       │ database, input file
#   sqlcmd -W -s "|"                   │ trim trailing spaces, "|" as column separator (-s takes ONE character)
run_sql_file() {
  case "$1" in
    postgres) docker compose exec -T postgres psql -q -U demo -d "$db" -f "$2" ;;
    mysql)    docker compose exec -T -e MYSQL_PWD=$PW mysql sh -c "mysql -uroot --default-character-set=utf8mb4 --table --force $db < $2" ;;
    mssql)    docker compose exec -T mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P $PW \
                -d "$db" -W -s "|" -i "$2" ;;
  esac
}

# Show what Liquibase really created: the common column report, then the scenario's own checks (if any).
inspect() {
  echo "--- columns"
  # See columns types created by Liquibase on the chosen engine
  run_sql_file "$1" "/common/inspect-$1.sql"
  if [ -f "$dir/inspect/$1.sql" ]; then
    echo "--- scenario checks"
    # See specific checks for this scenario and engine (if any)
    run_sql_file "$1" "/scenarios/$name/inspect/$1.sql"
  fi
}

# Drop and recreate the scenario's database, so every run starts empty.
#   exec -T                        │ Runs the engine's own client inside its running container, no pseudo-terminal
#   psql -q -U -d postgres -c      │ quiet, user, connect to the maintenance db "postgres", run a statement
#   WITH (FORCE)                   │ PostgreSQL 13+: disconnects open sessions before dropping
#   -e MYSQL_PWD                   │ password via environment (avoids the "password on command line" warning)
#   mysql -uroot -e                │ user root, run statements
#   sqlcmd -C                      │ trust the server certificate (self-signed)
#   sqlcmd -b                      │ exit with an error code if a statement fails
#   sqlcmd -S -U -P -Q             │ server, user, password, run the query and exit
#   SET SINGLE_USER ... IMMEDIATE  │ SQL Server: rolls back and disconnects open sessions before dropping
reset_db() {
  case "$1" in
    postgres) docker compose exec -T postgres psql -q -U demo -d postgres \
                -c "DROP DATABASE IF EXISTS $db WITH (FORCE)" -c "CREATE DATABASE $db" ;;
    mysql)    docker compose exec -T -e MYSQL_PWD=$PW mysql mysql -uroot \
                -e "DROP DATABASE IF EXISTS $db; CREATE DATABASE $db" ;;
    mssql)    docker compose exec -T mssql /opt/mssql-tools18/bin/sqlcmd -C -b -S localhost -U sa -P $PW \
                -Q "IF DB_ID('$db') IS NOT NULL BEGIN ALTER DATABASE $db SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE $db; END; CREATE DATABASE $db" ;;
  esac
}

# For every selected engine, run the mode via above functions (reset_db -> liquibase -> inspect).
for e in $engines; do
  echo
  echo "=================== $name | $e | $changelog | $mode ==================="
  case "$mode" in
    update)
      reset_db "$e" >/dev/null || { echo "database reset failed"; continue; }
      liquibase "$e" update || echo ">>> liquibase update FAILED on $e (inspecting what was left behind)"
      inspect "$e" ;;
    rerun)
      liquibase "$e" update || echo ">>> liquibase update FAILED on $e (inspecting what was left behind)"
      inspect "$e" ;;
    sql)
      reset_db "$e" >/dev/null || { echo "database reset failed"; continue; }
      liquibase "$e" update-sql ;;
    inspect)
      inspect "$e" ;;
    *)
      # any other Liquibase command (rollback, tag, history, ...) on the existing database
      liquibase "$e" "$mode" || echo ">>> liquibase $mode FAILED on $e"
      inspect "$e" ;;
  esac
done

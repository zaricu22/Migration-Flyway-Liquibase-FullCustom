#!/usr/bin/env bash
# Runs one Flyway scenario in its own PostgreSQL schema (schema name = lowercase scenario ID).
#
# Usage: ./run.sh <ID> [action] [arg]
#   migrate [version]   apply migrations (optionally only up to <version>)
#   info | validate     Flyway info / validate
#   repair              remove failed entries from the history (after a failed non-transactional migration)
#   clean               drop everything in the scenario schema
#   verify              run verify.sql with psql
#   sql <file>          run a scenario file with psql (app_v1.sql, demo_*.sql, ...)
#   psql                interactive PostgreSQL command line (psql) where you type SQL yourself and see the results;
#                       with search_path set to the scenario schema
#   all                 flyway clean + flyway migrate + psql verify
# Env:  LOCATIONS=<a,b>     migration folders inside the scenario, comma-separated (default: migrations)
#       FLYWAY_ARGS=<opts>  extra Flyway options, e.g. -outOfOrder=true
#
# Examples: ./run.sh B1 migrate 2 | ./run.sh B1 sql app_v1.sql | ./run.sh D2 all
#           LOCATIONS=migrations,late FLYWAY_ARGS=-outOfOrder=true ./run.sh C1 migrate
set -euo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: don't rewrite /scenarios/... into C:/...
cd "$(dirname "$0")"

# 1st Parameter, required, scenario ID (e.g. B1, D2, ...)
id=$(echo "${1:?usage: ./run.sh <ID> [migrate [version]|info|validate|clean|repair|verify|sql <file>|psql|all]}" | tr '[:lower:]' '[:upper:]')
# 2nd Parameter, default to "migrate"
action="${2:-migrate}"
# Derived parameters
dir=$(ls -d scenarios/"$id"-* 2>/dev/null | head -n 1 || true)
[ -n "$dir" ] || { echo "Unknown scenario '$id'. Available:"; ls scenarios; exit 1; }
name=$(basename "$dir")
schema=$(echo "$id" | tr '[:upper:]' '[:lower:]')
# Migration folders (LOCATIONS env, default "migrations") -> filesystem:/scenarios/<name>/<folder>,...
locations=$(echo "${LOCATIONS:-migrations}" | sed "s|[^,]*|filesystem:/scenarios/$name/&|g")

# Make sure the database container is running and ready before any script touches it.
#   docker compose   │ Works with the services defined in docker-compose.yml in the current folder
#   --progress quiet │ Hides the progress output
#   up               │ Creates and starts the service; does nothing if it's already running
#   -d               │ Detached mode (run in background)
#   --wait           │ Waits until the container is healthy before returning, using the healthcheck from the compose file
#   postgres         │ Only this service.
docker compose --progress quiet up -d --wait postgres

flyway() {
  #   run             │ Starts a new one-off container of the service and runs a command in it.
  #   --rm            │ Removes the container as soon as it finishes
  #   -T              │ No pseudo-terminal, so the output can be piped and filtered (scripts, CI).
  #   flyway          │ The service from the compose file (image, mounted scenarios, connection settings).
  #   -schemas        │ The PostgreSQL schema Flyway manages: It creates it if missing, keeps flyway_schema_history in it, and uses it as the default schema (search_path) while migrating.
  #                     This is what isolates the scenarios from each other
  #   -locations      │ Where the migration scripts are, inside the container (one or more folders)
  #   $FLYWAY_ARGS    │ Extra options from the environment (unquoted on purpose: split into words)
  #   "$@"            │ Everything else passed to the function: the Flyway command and extra options
  docker compose --progress quiet run --rm -T flyway \
    -schemas="$schema" \
    -locations="$locations" \
    ${FLYWAY_ARGS:-} \
    "$@"
}

psql_file() {
  #   exec              │ Runs a command in an already running container.
  #   -T                │ No pseudo-terminal, so the output can be piped and filtered (scripts, CI).
  #   -e PGOPTIONS      │ Sets an environment variable for this one command: search_path = scenario schema.
  #   postgres          │ The service/container to execute in.
  #   psql              │ The command to run inside the container.
  #   -U -d             │ psql: user and database
  #   -q                │ quiet: no "INSERT 0 1"-style status messages (results and NOTICEs still shown)
  #   -v ON_ERROR_STOP  │ s top at the first error with a non-zero exit code
  #   -f                │ the file to run (path inside the container, where ./scenarios is mounted)
  docker compose exec -T -e PGOPTIONS="-c search_path=$schema" postgres \
    psql -U demo -d demo -q -v ON_ERROR_STOP=1 -f "/scenarios/$name/$1"
}

# Based on the action, run the corresponding Flyway command or psql command, via above functions.
echo "== $name (schema: $schema) -> $action"
case "$action" in
  # 3rd Parameter is optional version for migrate (e.g. 2, 3, ...)
  migrate)  if [ -n "${3:-}" ]; then flyway -target="$3" migrate; else flyway migrate; fi ;;
  info|validate|clean|repair) flyway "$action" ;;
  verify)   psql_file verify.sql ;;
  # 3rd parameter is an optional file name to run with psql (e.g. app_v1.sql, demo_*.sql, ...
  sql)      psql_file "${3:?usage: ./run.sh $id sql <file>}" ;;
  psql)     docker compose exec -e PGOPTIONS="-c search_path=$schema" postgres psql -U demo -d demo ;;
  all)      flyway clean && flyway migrate && psql_file verify.sql ;;
  *)        echo "Unknown action '$action'"; exit 1 ;;
esac

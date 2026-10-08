-- The layers of the migration, physically separated:
--   src  foreign tables pointing at the OLD system (read-only window, via postgres_fdw)
--   raw  exact copy of the source (all text) + batch metadata
--   stg  cleansed, typed, mapped data in (almost) the target shape
--   mig  control tables: runs, errors (quarantine), mappings, id map, checks  -> kept as audit trail
--   public = the production (target) schema
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS mig;
CREATE SCHEMA IF NOT EXISTS src;

-- Connection to the old system. In real life: another server, another engine (then use a tool,
-- an export file or the matching FDW: oracle_fdw, tds_fdw, mysql_fdw ...).
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_foreign_server WHERE srvname = 'legacy_srv') THEN
        CREATE SERVER legacy_srv FOREIGN DATA WRAPPER postgres_fdw
            OPTIONS (host 'localhost', port '5432', dbname 'legacy_shop');
        CREATE USER MAPPING FOR CURRENT_USER SERVER legacy_srv
            OPTIONS (user 'demo', password 'demo');
    END IF;
END $$;

-- (Re)import the source table definitions as foreign tables in schema src.
DROP FOREIGN TABLE IF EXISTS src.customers, src.products, src.order_lines;
IMPORT FOREIGN SCHEMA legacy FROM SERVER legacy_srv INTO src;

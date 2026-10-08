-- Control tables. They are the memory of the migration: what ran, what was rejected and why,
-- how old keys map to new ones, and every check result. Never dropped (08_cleanup keeps them).

-- One row per pipeline run (full or delta), one row per phase of a run.
CREATE TABLE IF NOT EXISTS mig.run (
    run_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kind        text        NOT NULL,
    status      text        NOT NULL DEFAULT 'RUNNING',
    started_at  timestamptz NOT NULL DEFAULT clock_timestamp(),
    finished_at timestamptz
);
-- full = initial load, delta = incremental sync, cutover = freeze + final delta + smoke test + go/no-go
-- (dropped and re-added, so databases created with an older list get the new one)
ALTER TABLE mig.run DROP CONSTRAINT IF EXISTS run_kind_check;
ALTER TABLE mig.run ADD CONSTRAINT run_kind_check CHECK (kind IN ('full', 'delta', 'cutover'));

CREATE TABLE IF NOT EXISTS mig.run_phase (
    run_id      bigint      NOT NULL REFERENCES mig.run,
    phase       text        NOT NULL,
    status      text        NOT NULL,
    started_at  timestamptz NOT NULL,
    finished_at timestamptz,
    PRIMARY KEY (run_id, phase)
);

-- The quarantine: one row per problem found. REJECT = the record is not migrated,
-- WARN = migrated without that value (instead used NULL / missing, e.g. an unparseable phone number).
CREATE TABLE IF NOT EXISTS mig.error (
    error_id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_id      bigint      NOT NULL REFERENCES mig.run,
    phase       text        NOT NULL,
    entity      text        NOT NULL,          -- customer | product | order
    source_key  text        NOT NULL,          -- key in the OLD system
    column_name text,
    raw_value   text,
    rule        text        NOT NULL,
    severity    text        NOT NULL CHECK (severity IN ('REJECT', 'WARN')),
    message     text,
    logged_at   timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS error_run_entity_idx ON mig.error (run_id, entity, severity, source_key);

-- Value mappings (reference data for validation and transformation).
CREATE TABLE IF NOT EXISTS mig.code_map (
    entity   text NOT NULL,                    -- country | order_status
    old_code text NOT NULL,                    -- normalized: lower(btrim(value))
    new_code text NOT NULL,
    PRIMARY KEY (entity, old_code)
);

-- Old key -> new id, for every migrated record. Loads resolve foreign keys through it,
-- and it answers "where did legacy customer 1905 go?" forever.
CREATE TABLE IF NOT EXISTS mig.id_map (
    entity     text   NOT NULL,
    legacy_key text   NOT NULL,
    new_id     bigint NOT NULL,
    run_id     bigint NOT NULL REFERENCES mig.run,
    PRIMARY KEY (entity, legacy_key)
);

-- High-water marks for the incremental (delta) extract.
CREATE TABLE IF NOT EXISTS mig.watermark (
    entity          text PRIMARY KEY,
    extracted_until timestamp NOT NULL
);

-- Progress of long, batched steps: a killed load resumes after the last committed batch.
CREATE TABLE IF NOT EXISTS mig.checkpoint (
    job        text PRIMARY KEY,
    last_key   text NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

-- Every reconciliation / verification check with expected and actual value.
CREATE TABLE IF NOT EXISTS mig.reconciliation (
    run_id     bigint NOT NULL REFERENCES mig.run,
    phase      text   NOT NULL,
    check_name text   NOT NULL,
    expected   text,
    actual     text,
    ok         boolean NOT NULL,
    checked_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (run_id, phase, check_name)
);

-- Rejected source keys of the CURRENT run: everything downstream (transform, reconcile)
-- excludes exactly these.
CREATE OR REPLACE VIEW mig.v_rejected AS
SELECT DISTINCT entity, source_key
FROM mig.error
WHERE run_id = (SELECT max(run_id) FROM mig.run) AND severity = 'REJECT';

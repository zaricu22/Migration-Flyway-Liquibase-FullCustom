-- Helper functions. Two groups:
--   1. run bookkeeping + checks/gates (used by run.sh and the check scripts)
--   2. parsing / normalization rules (used by validation AND transformation, so both apply
--      exactly the same rule)

------------------------------------------------------------------------------------------------
-- 1. Runs, phases, checks, gates
------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mig.current_run() RETURNS bigint
LANGUAGE sql STABLE AS $$ SELECT max(run_id) FROM mig.run $$;

CREATE OR REPLACE FUNCTION mig.new_run(p_kind text) RETURNS bigint
LANGUAGE sql AS $$ INSERT INTO mig.run (kind) VALUES (p_kind) RETURNING run_id $$;

CREATE OR REPLACE FUNCTION mig.end_run(p_status text) RETURNS void
LANGUAGE sql AS $$
    UPDATE mig.run SET status = p_status, finished_at = clock_timestamp() WHERE run_id = mig.current_run()
$$;

CREATE OR REPLACE FUNCTION mig.phase_start(p_phase text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    IF mig.current_run() IS NULL THEN
        RAISE EXCEPTION 'No run yet: start with ./run.sh all';
    END IF;
    INSERT INTO mig.run_phase (run_id, phase, status, started_at)
    VALUES (mig.current_run(), p_phase, 'RUNNING', clock_timestamp())
    ON CONFLICT (run_id, phase) DO UPDATE
        SET status = 'RUNNING', started_at = clock_timestamp(), finished_at = NULL;
    -- retrying a failed phase re-opens the run
    UPDATE mig.run SET status = 'RUNNING', finished_at = NULL
    WHERE run_id = mig.current_run() AND status = 'FAILED';
END $$;

CREATE OR REPLACE FUNCTION mig.phase_end(p_phase text, p_status text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE mig.run_phase SET status = p_status, finished_at = clock_timestamp()
    WHERE run_id = mig.current_run() AND phase = p_phase;
    IF p_status = 'FAILED' THEN
        PERFORM mig.end_run('FAILED');
    END IF;
END $$;

-- Used by the load: production is only touched if the earlier gates of THIS run passed.
CREATE OR REPLACE FUNCTION mig.require_phase(p_phase text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM mig.run_phase
                   WHERE run_id = mig.current_run() AND phase = p_phase AND status = 'DONE') THEN
        RAISE EXCEPTION 'Phase % has not completed successfully in run %. Refusing to continue.',
            p_phase, mig.current_run();
    END IF;
END $$;

-- Record a check: expected vs actual (compared as text).
CREATE OR REPLACE FUNCTION mig.check(p_phase text, p_name text, p_expected anyelement, p_actual anyelement)
RETURNS boolean
LANGUAGE plpgsql AS $$
DECLARE
    v_ok boolean := p_expected IS NOT DISTINCT FROM p_actual;
BEGIN
    INSERT INTO mig.reconciliation (run_id, phase, check_name, expected, actual, ok)
    VALUES (mig.current_run(), p_phase, p_name, p_expected::text, p_actual::text, v_ok)
    ON CONFLICT (run_id, phase, check_name) DO UPDATE
        SET expected = EXCLUDED.expected, actual = EXCLUDED.actual, ok = EXCLUDED.ok,
            checked_at = clock_timestamp();
    RETURN v_ok;
END $$;

-- A gate: stop the pipeline if any check of this phase failed.
CREATE OR REPLACE FUNCTION mig.gate(p_phase text) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    r record;
    v_failed int := 0;
BEGIN
    FOR r IN SELECT check_name, expected, actual, ok FROM mig.reconciliation
             WHERE run_id = mig.current_run() AND phase = p_phase ORDER BY check_name LOOP
        RAISE NOTICE '% %  (expected %, actual %)',
            CASE WHEN r.ok THEN 'PASS' ELSE 'FAIL' END, r.check_name, r.expected, r.actual;
        IF NOT r.ok THEN v_failed := v_failed + 1; END IF;
    END LOOP;
    IF v_failed > 0 THEN
        RAISE EXCEPTION 'GATE %: % check(s) failed. The pipeline stops here.', p_phase, v_failed;
    END IF;
    RAISE NOTICE 'GATE %: passed', p_phase;
END $$;

------------------------------------------------------------------------------------------------
-- 2. Parsing and normalization rules
------------------------------------------------------------------------------------------------
-- 'YYYY-MM-DD' or 'DD.MM.YYYY' -> date; anything else (or an impossible date) -> NULL.
-- Whitelisting formats matters: PostgreSQL would also accept 'yesterday' or 'epoch' as a date.
CREATE OR REPLACE FUNCTION mig.parse_date(p text) RETURNS date
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    iso text := CASE
        WHEN btrim(p) ~ '^\d{4}-\d{2}-\d{2}$'   THEN btrim(p)
        WHEN btrim(p) ~ '^\d{2}\.\d{2}\.\d{4}$' THEN regexp_replace(btrim(p), '^(\d{2})\.(\d{2})\.(\d{4})$', '\3-\2-\1')
    END;
BEGIN
    RETURN CASE WHEN pg_input_is_valid(iso, 'date') THEN iso::date END;
END $$;

-- '12,50' / '12.50' / '12' -> 1250 cents; anything else -> NULL.
CREATE OR REPLACE FUNCTION mig.parse_amount_cents(p text) RETURNS bigint
LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN btrim(p) ~ '^\d{1,9}([.,]\d{1,2})?$'
                THEN round(replace(btrim(p), ',', '.')::numeric * 100)::bigint END
$$;

CREATE OR REPLACE FUNCTION mig.normalize_email(p text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$ SELECT lower(btrim(p)) $$;

-- E.164: '+...' keeps its country code; 10 digits not starting with 0 = North American number;
-- anything else (e.g. a local '064/...' number without country) -> NULL.
CREATE OR REPLACE FUNCTION mig.normalize_phone(p text) RETURNS text
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    digits text := regexp_replace(coalesce(p, ''), '\D', '', 'g');
    result text := CASE
        WHEN btrim(p) LIKE '+%'                          THEN '+' || digits
        WHEN length(digits) = 10 AND digits !~ '^0'      THEN '+1' || digits
    END;
BEGIN
    RETURN CASE WHEN result ~ '^\+[1-9][0-9]{7,14}$' THEN result END;
END $$;

-- 'Mary Ann  Evans' -> first 'Mary Ann', last 'Evans'; a single word is a first name only.
CREATE OR REPLACE FUNCTION mig.name_first(p text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
    SELECT regexp_replace(regexp_replace(btrim(p), '\s+', ' ', 'g'), '\s\S+$', '')
$$;

CREATE OR REPLACE FUNCTION mig.name_last(p text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
    SELECT substring(regexp_replace(btrim(p), '\s+', ' ', 'g') FROM '\s(\S+)$')
$$;

-- 'Main Street 5, 11005 Belgrade' -> {street, zip, city}; NULL if it doesn't match.
CREATE OR REPLACE FUNCTION mig.parse_address(p text) RETURNS text[]
LANGUAGE sql IMMUTABLE AS $$
    SELECT regexp_match(btrim(p), '^(.+?),\s*(\d{4,6})\s+(.+)$')
$$;

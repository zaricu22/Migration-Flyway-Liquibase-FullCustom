-- Set-based conversion with quarantine. No per-row exception handling (slow, one subtransaction
-- per row): pg_input_is_valid() / pg_input_error_info() (PostgreSQL 16+) test a cast without
-- raising an error.

-- Step 1: recognize KNOWN formats and rewrite them into one canonical text form.
--   Don't rely on the cast alone to decide what's valid:
--   * '31/12/2023' depends on the DateStyle setting (fails with MDY, works with DMY)
--   * 'yesterday', 'today', 'epoch', 'infinity' are VALID date inputs in PostgreSQL!
--   -> whitelist formats with a regex first, then validate the value.
CREATE TEMP TABLE staged ON COMMIT DROP AS
SELECT id,
       paid_on  AS paid_on_raw,
       amount   AS amount_raw,
       currency AS currency_raw,
       CASE
           WHEN paid_on ~ '^\d{4}-\d{2}-\d{2}$' THEN paid_on
           WHEN paid_on ~ '^\d{2}/\d{2}/\d{4}$' THEN regexp_replace(paid_on, '^(\d{2})/(\d{2})/(\d{4})$', '\3-\2-\1')
       END AS paid_on_iso,
       CASE
           WHEN amount ~ '^-?\d+(\.\d+)?$'           THEN amount
           WHEN amount ~ '^-?\d+,\d+$'               THEN replace(amount, ',', '.')
           WHEN amount ~ '^-?\d{1,3}(\.\d{3})+,\d+$' THEN replace(replace(amount, '.', ''), ',', '.')
       END AS amount_norm,
       upper(btrim(currency)) AS currency_norm
FROM legacy_payment;

-- Step 2: log every problem. UNION ALL of one check per rule; each rule says WHY.
INSERT INTO payment_migration_error (source_id, column_name, raw_value, error)
SELECT id, 'paid_on', paid_on_raw, 'unrecognized date format'
FROM staged WHERE paid_on_iso IS NULL
UNION ALL
SELECT id, 'paid_on', paid_on_raw, (pg_input_error_info(paid_on_iso, 'date')).message
FROM staged WHERE paid_on_iso IS NOT NULL AND NOT pg_input_is_valid(paid_on_iso, 'date')
UNION ALL
SELECT id, 'amount', amount_raw, 'unrecognized number format'
FROM staged WHERE amount_norm IS NULL
UNION ALL
SELECT id, 'amount', amount_raw, (pg_input_error_info(amount_norm, 'numeric(12,2)')).message
FROM staged WHERE amount_norm IS NOT NULL AND NOT pg_input_is_valid(amount_norm, 'numeric(12,2)')
UNION ALL
SELECT id, 'amount', amount_raw, 'amount must be positive'
FROM staged
-- CASE, not AND: SQL doesn't guarantee evaluation order, the cast could run on invalid input.
WHERE CASE WHEN pg_input_is_valid(amount_norm, 'numeric(12,2)') THEN amount_norm::numeric <= 0 ELSE false END
UNION ALL
SELECT id, 'currency', currency_raw, 'not a 3-letter currency code'
FROM staged WHERE currency_norm IS NULL OR currency_norm !~ '^[A-Z]{3}$';

-- Step 3: convert every row that has no problem.
INSERT INTO payment (id, paid_on, amount, currency)
SELECT id, paid_on_iso::date, amount_norm::numeric(12,2), currency_norm
FROM staged s
WHERE NOT EXISTS (SELECT 1 FROM payment_migration_error e WHERE e.source_id = s.id);

-- Step 4: a quality gate. A few bad rows are expected; many mean the rules are wrong
-- (e.g. a whole export in an unexpected format). Above 1%: roll back everything.
DO $$
DECLARE
    total    bigint;
    rejected bigint;
BEGIN
    SELECT count(*) INTO total FROM legacy_payment;
    SELECT count(DISTINCT source_id) INTO rejected FROM payment_migration_error;
    RAISE NOTICE '% of % rows quarantined (% %%)', rejected, total, round(100.0 * rejected / total, 2);
    IF rejected > total * 0.01 THEN
        RAISE EXCEPTION 'Too many rejected rows (% of %). Fix the conversion rules first.', rejected, total;
    END IF;
END $$;

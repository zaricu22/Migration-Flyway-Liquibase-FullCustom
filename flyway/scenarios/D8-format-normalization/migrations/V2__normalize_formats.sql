-- Normalization rules as IMMUTABLE functions: one definition, used by the migration now and by
-- CHECK constraints / the application later.

CREATE FUNCTION normalize_email(email text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
    SELECT lower(btrim(email))
$$;

CREATE FUNCTION normalize_name(name text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
    SELECT regexp_replace(btrim(name), '\s+', ' ', 'g')
$$;

-- E.164 (+<country><number>, max 15 digits). Rules, in order:
--   '+...'      -> keep the digits, it already has a country code
--   '00...'     -> international prefix, replace 00 with +
--   11 digits starting with 1 -> North American number with country code
--   10 digits   -> North American number without country code (business default: +1)
--   anything else -> NULL (unparseable; the original is kept in phone_raw)
CREATE FUNCTION normalize_phone(phone text) RETURNS text
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    digits text := regexp_replace(coalesce(phone, ''), '\D', '', 'g');
    result text;
BEGIN
    result := CASE
        WHEN btrim(phone) LIKE '+%'                           THEN '+' || digits
        WHEN digits LIKE '00%'                                THEN '+' || substr(digits, 3)
        WHEN length(digits) = 11 AND digits LIKE '1%'         THEN '+' || digits
        WHEN length(digits) = 10                              THEN '+1' || digits
    END;
    RETURN CASE WHEN result ~ '^\+[1-9][0-9]{7,14}$' THEN result END;
END $$;

-- PRE-FLIGHT: lowercasing emails can turn distinct values into duplicates
-- ('Ana@x.com' and 'ana@x.com'). Stop here and deduplicate first (D4) if that happens.
DO $$
DECLARE
    collisions bigint;
BEGIN
    SELECT count(*) INTO collisions
    FROM (SELECT normalize_email(email) FROM customer GROUP BY 1 HAVING count(*) > 1) d;
    IF collisions > 0 THEN
        RAISE EXCEPTION 'Normalizing emails would create % duplicate groups. Run a deduplication (D4) first.', collisions;
    END IF;
END $$;

-- Keep the original phone: the rules are lossy and may need revisiting.
ALTER TABLE customer ADD COLUMN phone_raw varchar(50);

-- Only touch rows that actually change: every UPDATE writes a new row version (bloat, WAL,
-- triggers), so "SET x = f(x)" on already-clean rows is pure cost.
UPDATE customer
SET email     = normalize_email(email),
    full_name = normalize_name(full_name),
    phone     = normalize_phone(phone),
    phone_raw = CASE WHEN phone IS DISTINCT FROM normalize_phone(phone) THEN phone END
WHERE email     IS DISTINCT FROM normalize_email(email)
   OR full_name IS DISTINCT FROM normalize_name(full_name)
   OR phone     IS DISTINCT FROM normalize_phone(phone);

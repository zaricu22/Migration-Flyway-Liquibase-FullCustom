-- 1. The mapping lives in a TABLE, not in a long CASE: it's reviewable, queryable, joinable
--    and stays as documentation. Many-to-one is fine ('N' and 'PEND' -> 'new').
CREATE TABLE status_mapping (
    old_code varchar(20) PRIMARY KEY,
    new_code varchar(20) NOT NULL
);

INSERT INTO status_mapping (old_code, new_code) VALUES
    ('N',    'new'),
    ('PEND', 'new'),
    ('P',    'paid'),
    ('S',    'shipped'),
    ('X',    'cancelled');   -- ...or 'refunded', see the conditional rule below

-- 2. PRE-FLIGHT: fail the migration (and roll back) if the data contains codes nobody mapped.
--    Better to stop here than to silently turn unknown codes into NULL or a default.
DO $$
DECLARE
    unmapped text;
BEGIN
    SELECT string_agg(DISTINCT o.status, ', ') INTO unmapped
    FROM orders o
    WHERE NOT EXISTS (SELECT 1 FROM status_mapping m WHERE m.old_code = o.status);

    IF unmapped IS NOT NULL THEN
        RAISE EXCEPTION 'Unmapped status codes: %. Add them to status_mapping first.', unmapped;
    END IF;
END $$;

-- 3. The new rule, NOT VALID: new writes must use new codes, old rows are converted in V3.
ALTER TABLE orders ADD CONSTRAINT orders_status_valid
    CHECK (status IN ('new', 'paid', 'shipped', 'cancelled', 'refunded')) NOT VALID;

-- 4. App v1 still writes old codes: translate them on the fly (BEFORE trigger runs before the CHECK).
CREATE FUNCTION orders_translate_status() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    mapped varchar(20);
BEGIN
    SELECT new_code INTO mapped FROM status_mapping WHERE old_code = NEW.status;
    IF FOUND THEN
        NEW.status := CASE WHEN NEW.status = 'X' AND NEW.refunded_at IS NOT NULL THEN 'refunded' ELSE mapped END;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER orders_translate_status
    BEFORE INSERT OR UPDATE OF status ON orders
    FOR EACH ROW EXECUTE FUNCTION orders_translate_status();

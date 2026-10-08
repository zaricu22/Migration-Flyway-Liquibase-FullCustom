-- EXPAND: add the new columns + keep old and new representation in sync.
-- Splitting rule (a business decision, write it down!): the last word is the last name,
-- everything before it is the first name. A single word is a first name only.
ALTER TABLE customer ADD COLUMN first_name varchar(100);
ALTER TABLE customer ADD COLUMN last_name  varchar(100);

CREATE FUNCTION name_first(full_name text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
    SELECT regexp_replace(regexp_replace(trim(full_name), '\s+', ' ', 'g'), '\s\S+$', '')
$$;

CREATE FUNCTION name_last(full_name text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
    SELECT substring(regexp_replace(trim(full_name), '\s+', ' ', 'g') FROM '\s(\S+)$')
$$;

CREATE FUNCTION customer_sync_name() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.first_name IS NULL AND NEW.last_name IS NULL THEN      -- app v1: full_name only
            NEW.first_name := name_first(NEW.full_name);
            NEW.last_name  := name_last(NEW.full_name);
        ELSE                                                           -- app v2: parts only
            NEW.full_name := concat_ws(' ', NEW.first_name, NEW.last_name);
        END IF;
    ELSIF NEW.full_name IS DISTINCT FROM OLD.full_name THEN           -- app v1 updated
        NEW.first_name := name_first(NEW.full_name);
        NEW.last_name  := name_last(NEW.full_name);
    ELSIF NEW.first_name IS DISTINCT FROM OLD.first_name
       OR NEW.last_name  IS DISTINCT FROM OLD.last_name THEN          -- app v2 updated
        NEW.full_name := concat_ws(' ', NEW.first_name, NEW.last_name);
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER customer_sync_name
    BEFORE INSERT OR UPDATE ON customer
    FOR EACH ROW EXECUTE FUNCTION customer_sync_name();

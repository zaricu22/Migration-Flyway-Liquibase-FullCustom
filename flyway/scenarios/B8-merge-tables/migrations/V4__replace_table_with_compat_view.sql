-- Switch the source of truth to customer. The old table is replaced by a view with the same
-- name and columns, so app v1 keeps working unchanged.
--
-- This view is NOT automatically updatable the way we need: an INSERT into it would try to
-- create a new customer row. INSTEAD OF triggers define what "insert a profile" means now:
-- an UPDATE of the existing customer.
SET LOCAL lock_timeout = '5s';

DROP TRIGGER customer_profile_to_customer ON customer_profile;
DROP FUNCTION customer_profile_to_customer();
DROP TABLE customer_profile;

CREATE VIEW customer_profile AS
SELECT id AS customer_id, bio, avatar_url
FROM customer
WHERE bio IS NOT NULL OR avatar_url IS NOT NULL;   -- "has a profile"

CREATE FUNCTION customer_profile_view_write() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE customer SET bio = NULL, avatar_url = NULL WHERE id = OLD.customer_id;
        RETURN OLD;
    END IF;

    UPDATE customer SET bio = NEW.bio, avatar_url = NEW.avatar_url WHERE id = NEW.customer_id;
    IF NOT FOUND THEN
        -- same error the old FK would have raised
        RAISE foreign_key_violation USING MESSAGE = format('customer %s does not exist', NEW.customer_id);
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER customer_profile_view_write
    INSTEAD OF INSERT OR UPDATE OR DELETE ON customer_profile
    FOR EACH ROW EXECUTE FUNCTION customer_profile_view_write();

-- >>> Deploy app v2 (reads/writes customer.bio / avatar_url) before V5. <<<

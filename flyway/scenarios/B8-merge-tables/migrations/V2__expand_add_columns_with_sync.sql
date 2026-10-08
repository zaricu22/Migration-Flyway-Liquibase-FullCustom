-- EXPAND: target columns on customer + one-way sync from the old table.
-- Only app v1 writes customer_profile at this point, so one direction is enough.
ALTER TABLE customer ADD COLUMN bio        text;
ALTER TABLE customer ADD COLUMN avatar_url varchar(500);

CREATE FUNCTION customer_profile_to_customer() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE customer SET bio = NULL, avatar_url = NULL WHERE id = OLD.customer_id;
    ELSE
        UPDATE customer SET bio = NEW.bio, avatar_url = NEW.avatar_url WHERE id = NEW.customer_id;
    END IF;
    RETURN NULL;
END $$;

CREATE TRIGGER customer_profile_to_customer
    AFTER INSERT OR UPDATE OR DELETE ON customer_profile
    FOR EACH ROW EXECUTE FUNCTION customer_profile_to_customer();

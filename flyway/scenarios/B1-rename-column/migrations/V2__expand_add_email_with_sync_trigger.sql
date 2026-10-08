-- EXPAND: add the new column next to the old one, and keep both in sync while app v1
-- (writes "mail") and app v2 (writes "email") run side by side.
-- A plain RENAME COLUMN would break every running app v1 instance instantly.
ALTER TABLE customer ADD COLUMN email varchar(255);

CREATE FUNCTION customer_sync_mail_email() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- app v1 sets only mail, app v2 sets only email: fill the other one
        NEW.email := COALESCE(NEW.email, NEW.mail);
        NEW.mail  := COALESCE(NEW.mail, NEW.email);
    ELSIF NEW.email IS DISTINCT FROM OLD.email THEN
        NEW.mail := NEW.email;          -- app v2 changed email
    ELSIF NEW.mail IS DISTINCT FROM OLD.mail THEN
        NEW.email := NEW.mail;          -- app v1 changed mail
    END IF;
    RETURN NEW;
END $$;

-- BEFORE trigger: runs before the NOT NULL check on mail, so inserts from app v2
-- (without mail) still pass.
CREATE TRIGGER customer_sync_mail_email
    BEFORE INSERT OR UPDATE ON customer
    FOR EACH ROW EXECUTE FUNCTION customer_sync_mail_email();

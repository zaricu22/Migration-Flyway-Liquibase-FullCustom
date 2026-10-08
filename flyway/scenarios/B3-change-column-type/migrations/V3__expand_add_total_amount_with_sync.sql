-- float8 -> numeric changes the on-disk format: ALTER COLUMN TYPE would rewrite the table
-- under ACCESS EXCLUSIVE (no reads, no writes). Instead: EXPAND with a new column.
--
-- Two columns can't share a name, so the new column gets a new name (total_amount).
-- Keeping the old name would need one more rename step and one more app deploy.
ALTER TABLE orders ADD COLUMN total_amount numeric(12,2);

CREATE FUNCTION orders_sync_amount() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.total_amount := COALESCE(NEW.total_amount, round(NEW.amount::numeric, 2));
        NEW.amount       := COALESCE(NEW.amount, NEW.total_amount::float8);
    ELSIF NEW.total_amount IS DISTINCT FROM OLD.total_amount THEN
        NEW.amount := NEW.total_amount::float8;                  -- app v2 wrote
    ELSIF NEW.amount IS DISTINCT FROM OLD.amount THEN
        NEW.total_amount := round(NEW.amount::numeric, 2);        -- app v1 wrote
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER orders_sync_amount
    BEFORE INSERT OR UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION orders_sync_amount();

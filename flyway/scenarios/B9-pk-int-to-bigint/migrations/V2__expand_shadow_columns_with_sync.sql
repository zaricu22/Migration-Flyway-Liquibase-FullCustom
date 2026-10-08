-- ALTER COLUMN id TYPE bigint would rewrite customer AND orders (plus all their indexes)
-- under ACCESS EXCLUSIVE locks. Instead: bigint "shadow" columns kept in sync by triggers.
-- The application doesn't change at all: at the end the shadow columns take over the old names.
ALTER TABLE customer ADD COLUMN id_new bigint;
ALTER TABLE orders   ADD COLUMN customer_id_new bigint;

CREATE FUNCTION customer_sync_id_new() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.id_new := NEW.id;           -- identity default is already applied in BEFORE triggers
    RETURN NEW;
END $$;

CREATE TRIGGER customer_sync_id_new
    BEFORE INSERT OR UPDATE OF id ON customer
    FOR EACH ROW EXECUTE FUNCTION customer_sync_id_new();

CREATE FUNCTION orders_sync_customer_id_new() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.customer_id_new := NEW.customer_id;
    RETURN NEW;
END $$;

CREATE TRIGGER orders_sync_customer_id_new
    BEFORE INSERT OR UPDATE OF customer_id ON orders
    FOR EACH ROW EXECUTE FUNCTION orders_sync_customer_id_new();

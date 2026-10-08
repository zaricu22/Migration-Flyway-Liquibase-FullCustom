-- New derived column. Nullable -> instant (A2).
ALTER TABLE orders ADD COLUMN order_number varchar(20);

-- NEW rows get their value right away, so the backfill (V3) only has to handle OLD rows
-- and doesn't chase a moving target.
CREATE FUNCTION orders_set_order_number() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.order_number := 'ORD-' || lpad(NEW.id::text, 10, '0');
    RETURN NEW;
END $$;

CREATE TRIGGER orders_set_order_number
    BEFORE INSERT ON orders
    FOR EACH ROW EXECUTE FUNCTION orders_set_order_number();

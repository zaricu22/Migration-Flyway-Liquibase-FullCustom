-- Constant defaults -> no rewrite (A3).
ALTER TABLE customer ADD COLUMN orders_count  integer NOT NULL DEFAULT 0;
ALTER TABLE customer ADD COLUMN last_order_at timestamptz;

-- The trigger goes in BEFORE the backfill, so no change is missed from now on.
-- Counters are incremental (+1 / -1). A MAX can't be "decremented": deleting the latest order
-- requires recomputing it from the remaining rows.
CREATE FUNCTION orders_maintain_customer_counters() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        UPDATE customer
        SET orders_count  = orders_count + 1,
            last_order_at = greatest(last_order_at, NEW.created_at)
        WHERE id = NEW.customer_id;
    END IF;

    IF TG_OP IN ('DELETE', 'UPDATE') THEN
        UPDATE customer
        SET orders_count  = orders_count - 1,
            last_order_at = (SELECT max(created_at) FROM orders WHERE customer_id = OLD.customer_id)
        WHERE id = OLD.customer_id;
    END IF;
    RETURN NULL;
END $$;

CREATE TRIGGER orders_maintain_customer_counters
    AFTER INSERT OR DELETE OR UPDATE OF customer_id ON orders
    FOR EACH ROW EXECUTE FUNCTION orders_maintain_customer_counters();

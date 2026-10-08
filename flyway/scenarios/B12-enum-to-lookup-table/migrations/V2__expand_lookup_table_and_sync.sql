-- EXPAND: a lookup table for the statuses, a text column referencing it, and a trigger that keeps
-- the enum column (app v1) and the code column (app v2) in sync both ways.
--
-- The table can't be called "order_status": every table also creates a row type with its own
-- name, and the enum type already uses that name.
CREATE TABLE order_status_code (
    code       text PRIMARY KEY,
    label      text NOT NULL,
    sort_order int  NOT NULL
);
INSERT INTO order_status_code (code, label, sort_order) VALUES
    ('new',       'New',       10),
    ('paid',      'Paid',      20),
    ('shipped',   'Shipped',   30),
    ('on_hold',   'On hold',   40),    -- still used by existing rows; removed in V3
    ('cancelled', 'Cancelled', 50);

ALTER TABLE orders ADD COLUMN status_code text;
-- NOT VALID: checks new and changed rows only; existing rows are validated in V3 after the backfill (A6)
ALTER TABLE orders ADD CONSTRAINT orders_status_code_fk
    FOREIGN KEY (status_code) REFERENCES order_status_code (code) NOT VALID;

CREATE FUNCTION orders_sync_status() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.status_code IS NOT NULL THEN
            NEW.status := NEW.status_code::order_status;   -- app v2 wrote the code
        ELSE
            NEW.status_code := NEW.status::text;           -- app v1 wrote the enum
        END IF;
    ELSIF NEW.status_code IS DISTINCT FROM OLD.status_code THEN
        NEW.status := NEW.status_code::order_status;       -- app v2 changed the code
    ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
        NEW.status_code := NEW.status::text;               -- app v1 changed the enum
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER orders_sync_status
    BEFORE INSERT OR UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION orders_sync_status();

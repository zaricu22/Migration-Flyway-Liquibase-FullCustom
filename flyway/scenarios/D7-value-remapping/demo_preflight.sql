-- What the pre-flight check in V2 does when the data contains a code nobody mapped.
-- (Runs in a transaction that is rolled back; run it after V2.)
\set ON_ERROR_STOP off
BEGIN;
ALTER TABLE orders DISABLE TRIGGER orders_translate_status;
ALTER TABLE orders DROP CONSTRAINT orders_status_valid;
INSERT INTO orders (status) VALUES ('ZZ'), ('Q');

DO $$
DECLARE
    unmapped text;
BEGIN
    SELECT string_agg(DISTINCT o.status, ', ') INTO unmapped
    FROM orders o
    WHERE NOT EXISTS (SELECT 1 FROM status_mapping m WHERE m.old_code = o.status)
      AND o.status NOT IN ('new', 'paid', 'shipped', 'cancelled', 'refunded');
    IF unmapped IS NOT NULL THEN
        RAISE EXCEPTION 'Unmapped status codes: %. Add them to status_mapping first.', unmapped;
    END IF;
END $$;
ROLLBACK;

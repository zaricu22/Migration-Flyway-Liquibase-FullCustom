-- Euros as float -> integer cents.
-- floor(price * 100) or a truncating cast is WRONG: 0.29 is stored as 0.28999999999999998,
-- so 0.29 * 100 = 28.999999999999996 -> 28 cents. round() is required.
ALTER TABLE orders ADD COLUMN price_cents bigint;

UPDATE orders SET price_cents = round(price * 100)::bigint;

-- Assert before dropping the source column: every converted value is within half a cent of
-- the original, and the totals match. If not, the whole migration rolls back.
DO $$
DECLARE
    bad bigint;
    diff numeric;
BEGIN
    SELECT count(*) INTO bad FROM orders WHERE abs(price_cents - price * 100) >= 0.5;
    SELECT abs(sum(price_cents) - round(sum(price::numeric) * 100)) INTO diff FROM orders;
    IF bad > 0 OR diff > 0 THEN
        RAISE EXCEPTION 'Conversion check failed: % rows off by >= 0.5 cent, total differs by % cents', bad, diff;
    END IF;
END $$;

ALTER TABLE orders ALTER COLUMN price_cents SET NOT NULL;
ALTER TABLE orders DROP COLUMN price;

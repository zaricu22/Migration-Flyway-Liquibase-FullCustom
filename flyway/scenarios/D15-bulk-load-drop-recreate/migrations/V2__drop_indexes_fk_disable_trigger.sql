-- Every index, FK and row trigger costs something PER INSERTED ROW. For a load that's large
-- relative to the table, it's much cheaper to drop them, load, and rebuild them once
-- (one sorted index build instead of 400,000 random index insertions).
--
-- ONLY in a maintenance window, or for a table the application isn't using yet: while the
-- indexes are gone, queries are slow, and while the FK/unique index are gone, nothing stops
-- bad data from other writers.
DROP INDEX product_name_idx;
DROP INDEX product_category_idx;
DROP INDEX product_sku_uq;                         -- re-created in V4 (which also re-checks uniqueness)
ALTER TABLE product DROP CONSTRAINT product_category_fk;

-- Disable only OUR trigger. "DISABLE TRIGGER ALL" would also disable the internal FK triggers.
ALTER TABLE product DISABLE TRIGGER product_touch_updated_at;

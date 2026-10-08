-- EXPAND: rename the table and, in the SAME transaction, create a view with the old name.
-- There is no moment where neither name exists. Indexes, constraints, FKs and grants follow
-- the table automatically.
SET LOCAL lock_timeout = '5s';

ALTER TABLE item RENAME TO product;

-- Tidy up names that still say "item" (cosmetic, but schema-diff tools will thank you).
ALTER INDEX item_pkey RENAME TO product_pkey;
ALTER SEQUENCE item_id_seq RENAME TO product_id_seq;

-- A simple single-table view is automatically updatable: app v1 keeps doing
-- SELECT / INSERT / UPDATE / DELETE on "item" and the rows land in "product".
-- Note: the view's column list is fixed now. Columns added to product later won't show up in it,
-- which is fine because app v1 doesn't know them.
CREATE VIEW item AS SELECT id, name, price FROM product;

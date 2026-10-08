-- The ORIGINAL V2, as it was applied to every database.
ALTER TABLE orders ADD COLUMN status text NOT NULL DEFAULT 'new';

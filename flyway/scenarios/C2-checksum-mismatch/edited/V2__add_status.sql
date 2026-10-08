-- The repository AFTER someone edited the already-applied V2: the default changed from 'new' to 'open'.
-- (V1 in this folder is an unchanged copy.)
-- Databases that already ran V2 still have 'new'. Only fresh databases would get 'open'.
ALTER TABLE orders ADD COLUMN status text NOT NULL DEFAULT 'open';

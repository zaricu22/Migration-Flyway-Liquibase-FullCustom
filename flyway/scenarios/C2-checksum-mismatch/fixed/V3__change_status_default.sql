-- The RIGHT way to change what V2 did: V2 stays untouched, a new migration makes the change.
-- Every database (old or fresh) ends up with the same result, by the same path.
ALTER TABLE orders ALTER COLUMN status SET DEFAULT 'open';

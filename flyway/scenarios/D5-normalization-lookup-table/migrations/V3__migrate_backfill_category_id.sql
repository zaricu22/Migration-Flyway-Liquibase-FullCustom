-- MIGRATE: join on the SAME normalized key that built the lookup table.
-- (Updating only category_id doesn't fire the "UPDATE OF category" trigger.)
UPDATE product p
SET category_id = c.id
FROM category c
WHERE lower(trim(p.category)) = lower(trim(c.name))
  AND p.category_id IS NULL;

-- >>> Deploy app v2 (writes category_id, reads the name via JOIN) before V4. <<<

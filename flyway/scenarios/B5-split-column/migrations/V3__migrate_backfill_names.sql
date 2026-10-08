-- MIGRATE: split existing rows. (The trigger re-joins full_name from the parts, which also
-- normalizes whitespace: '  Alan   Turing  ' -> 'Alan Turing'.)
UPDATE customer
SET first_name = name_first(full_name),
    last_name  = name_last(full_name)
WHERE first_name IS NULL;

ALTER TABLE customer ALTER COLUMN first_name SET NOT NULL;   -- last_name stays nullable ('Cher')

-- >>> Deploy app v2 (first_name/last_name only) before V4. <<<

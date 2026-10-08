-- MIGRATE: copy existing addresses. ON CONFLICT: rows the trigger already created stay as they are.
-- The address trigger fires for each row, but IS DISTINCT FROM turns it into a no-op.
INSERT INTO address (customer_id, street, city, zip)
SELECT id, street, city, zip
FROM customer
WHERE street IS NOT NULL OR city IS NOT NULL OR zip IS NOT NULL
ON CONFLICT (customer_id) DO NOTHING;

-- >>> Deploy app v2 (reads/writes address) before V4. <<<

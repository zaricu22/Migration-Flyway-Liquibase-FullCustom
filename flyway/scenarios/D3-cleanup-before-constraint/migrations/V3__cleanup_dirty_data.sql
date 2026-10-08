-- Step 2: fix the existing rows. Every rule is a BUSINESS decision. Document it here.
--
-- TRAP: a NOT VALID CHECK does not check old rows, but it DOES check every NEW row version.
-- An UPDATE creates a new row version, so "UPDATE orders SET status = 'paid'" on a row
-- that ALSO has quantity = -2 fails with orders_quantity_positive.
-- -> Fix all columns of a row in ONE update, or remove rows that can't be fixed first.

-- Rows that can't be repaired are not silently deleted: they go to a quarantine table
-- with the reason, so someone can look at them later.
CREATE TABLE orders_rejected (
    LIKE orders,
    reason      text        NOT NULL,
    rejected_at timestamptz NOT NULL DEFAULT now()
);

-- Rule 1: orphan orders (customer doesn't exist) -> quarantine.
WITH moved AS (
    DELETE FROM orders o
    WHERE NOT EXISTS (SELECT 1 FROM customer c WHERE c.id = o.customer_id)
    RETURNING o.*
)
INSERT INTO orders_rejected (id, customer_id, quantity, status, reason)
SELECT id, customer_id, quantity, status, 'orphan: customer does not exist' FROM moved;

-- Rule 2: quantity = 0 is meaningless -> quarantine.
WITH moved AS (
    DELETE FROM orders WHERE quantity = 0 RETURNING *
)
INSERT INTO orders_rejected (id, customer_id, quantity, status, reason)
SELECT id, customer_id, quantity, status, 'quantity is 0' FROM moved;

-- Rules 3 + 4 in ONE statement (see TRAP above):
--   negative quantity = sign bug in an old client -> abs()
--   status: normalize case/whitespace, map a known typo, anything else -> 'on_hold' for review
UPDATE orders
SET quantity = abs(quantity),
    status   = CASE
                   WHEN lower(trim(status)) IN ('new', 'paid', 'shipped', 'cancelled') THEN lower(trim(status))
                   WHEN lower(trim(status)) = 'shiped' THEN 'shipped'
                   ELSE 'on_hold'
               END
WHERE quantity < 0
   OR status NOT IN ('new', 'paid', 'shipped', 'cancelled', 'on_hold');

-- Rule 5: customers without email -> a unique, clearly fake placeholder (not deliverable).
UPDATE customer
SET email = 'missing+' || id || '@invalid.example'
WHERE email IS NULL;

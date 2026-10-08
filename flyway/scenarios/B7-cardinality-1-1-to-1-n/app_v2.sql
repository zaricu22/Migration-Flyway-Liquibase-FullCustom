-- NEW application: many addresses, one primary. Needs V4 to add a second address.
\echo '--- app v2: add a second (non-primary) address for customer 2'
INSERT INTO address (customer_id, street, city, is_primary) VALUES (2, '2 Holiday Road', 'Split', false);

\echo '--- app v2: make it the primary one (unset old primary first: the partial unique index is checked per row)'
BEGIN;
UPDATE address SET is_primary = false WHERE customer_id = 2 AND is_primary;
UPDATE address SET is_primary = true
WHERE id = (SELECT max(id) FROM address WHERE customer_id = 2);
COMMIT;

SELECT id, customer_id, street, city, is_primary FROM address WHERE customer_id = 2 ORDER BY id;

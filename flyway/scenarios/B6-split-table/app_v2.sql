-- NEW application: address table. Works from V3 on (and after V4).
\echo '--- app v2: change address through the address table'
UPDATE address SET city = 'Munich' WHERE customer_id = 2;
SELECT c.id, a.street, a.city, a.zip FROM customer c LEFT JOIN address a ON a.customer_id = c.id
WHERE c.id IN (1, 2, 5) ORDER BY c.id;

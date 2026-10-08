-- OLD application: address columns on customer. Works until V4.
\echo '--- app v1: new customer with address + address change'
INSERT INTO customer (email, street, city, zip) VALUES ('v1@example.com', '1 Old Road', 'Belgrade', '11000');
UPDATE customer SET city = 'Novi Sad' WHERE id = 1;

SELECT c.id, c.city AS customer_city, a.city AS address_city
FROM customer c LEFT JOIN address a ON a.customer_id = c.id
WHERE c.id IN (1, 2) OR c.id = (SELECT max(id) FROM customer) ORDER BY c.id;

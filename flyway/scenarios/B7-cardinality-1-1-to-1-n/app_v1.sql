-- OLD application: one address per customer, upsert keyed by customer_id.
-- Works until V4. After V4: "there is no unique or exclusion constraint matching the ON CONFLICT specification".
\echo '--- app v1: upsert the address of customer 1'
INSERT INTO address (customer_id, street, city) VALUES (1, '1 Upserted Street', 'Belgrade')
ON CONFLICT (customer_id) DO UPDATE SET street = EXCLUDED.street, city = EXCLUDED.city;

SELECT customer_id, street, city FROM address WHERE customer_id = 1;

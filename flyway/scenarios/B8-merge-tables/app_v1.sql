-- OLD application: writes customer_profile. Works on the table (V1-V3) and on the view (V4).
\echo '--- app v1: create a profile for customer 1, update the one of customer 3, delete the one of customer 6'
INSERT INTO customer_profile (customer_id, bio, avatar_url) VALUES (1, 'Written by app v1', NULL);
UPDATE customer_profile SET bio = 'Updated by app v1' WHERE customer_id = 3;
DELETE FROM customer_profile WHERE customer_id = 6;

SELECT c.id, c.bio AS customer_bio, p.bio AS profile_bio
FROM customer c LEFT JOIN customer_profile p ON p.customer_id = c.id
WHERE c.id IN (1, 3, 6) ORDER BY c.id;

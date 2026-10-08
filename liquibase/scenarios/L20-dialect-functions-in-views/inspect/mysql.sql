-- CONCAT with a NULL argument -> NULL (Cher has no last name)
SELECT * FROM customer_display ORDER BY id;
SELECT * FROM recent_customer ORDER BY id;
SELECT * FROM oldest_customers;
-- || is LOGICAL OR in MySQL: 'a' || 'b' -> 0 (with a deprecation warning), no error:
SELECT 'a' || 'b' AS pipes;

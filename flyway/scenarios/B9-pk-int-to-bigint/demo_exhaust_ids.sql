-- Burn through the remaining ids. Before V7: fails with "nextval: reached maximum value of
-- sequence" at 2,147,483,647 (an identity on an int column gets an int sequence). After V7: keeps going.
\set ON_ERROR_STOP off
INSERT INTO customer (email)
SELECT 'bulk' || g || '@example.com' FROM generate_series(1, 1500) AS g;

SELECT max(id) AS max_customer_id, max(id) > 2147483647 AS beyond_int_range FROM customer;

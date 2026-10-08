-- Address: split the free-text field into street / zip / city (a 1:1 child table in the target).
-- Unparseable addresses were reported as WARN in validation: the customer is migrated without one.
INSERT INTO stg.address (legacy_cust_no, street, zip, city)
SELECT c.legacy_cust_no, p[1], p[2], p[3]
FROM stg.customer c
JOIN raw.v_customers r ON r.cust_no::int = c.legacy_cust_no
CROSS JOIN LATERAL (SELECT mig.parse_address(r.address) AS p) parsed
WHERE p IS NOT NULL;

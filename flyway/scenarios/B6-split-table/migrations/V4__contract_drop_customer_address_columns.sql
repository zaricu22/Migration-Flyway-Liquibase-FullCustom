SET LOCAL lock_timeout = '5s';

DROP TRIGGER customer_to_address ON customer;
DROP TRIGGER address_to_customer ON address;
DROP FUNCTION customer_to_address();
DROP FUNCTION address_to_customer();

ALTER TABLE customer DROP COLUMN street, DROP COLUMN city, DROP COLUMN zip;

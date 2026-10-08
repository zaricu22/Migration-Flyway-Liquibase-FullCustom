-- Scans the table under SHARE UPDATE EXCLUSIVE: reads and writes keep working.
ALTER TABLE customer VALIDATE CONSTRAINT customer_country_code_not_null;

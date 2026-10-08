-- NOT NULL the safe way (B4): CHECK NOT VALID -> VALIDATE -> SET NOT NULL without a scan.
SET LOCAL lock_timeout = '5s';
ALTER TABLE customer ADD CONSTRAINT customer_public_id_not_null CHECK (public_id IS NOT NULL) NOT VALID;

-- Keep the data canonical from now on. The CHECKs reuse the same functions as the migration.
-- (Small table -> plain ADD CONSTRAINT. For big tables: NOT VALID + VALIDATE, see A6.)
ALTER TABLE customer ADD CONSTRAINT customer_email_normalized  CHECK (email = normalize_email(email));
ALTER TABLE customer ADD CONSTRAINT customer_name_normalized   CHECK (full_name = normalize_name(full_name));
ALTER TABLE customer ADD CONSTRAINT customer_phone_e164        CHECK (phone ~ '^\+[1-9][0-9]{7,14}$');

-- With canonical emails a plain unique constraint is enough (no lower() index needed).
ALTER TABLE customer ADD CONSTRAINT customer_email_uq UNIQUE (email);

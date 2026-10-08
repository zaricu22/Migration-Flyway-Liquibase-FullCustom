-- Metadata-only finish: NOT NULL (proven by the validated CHECK), unique constraint from the
-- existing index (A5).
SET LOCAL lock_timeout = '5s';

ALTER TABLE customer ALTER COLUMN public_id SET NOT NULL;
ALTER TABLE customer DROP CONSTRAINT customer_public_id_not_null;
ALTER TABLE customer ADD CONSTRAINT customer_public_id_uq UNIQUE USING INDEX customer_public_id_uq;

INSERT INTO _demo_filenode VALUES ('2 after V7', pg_relation_filenode('customer'));

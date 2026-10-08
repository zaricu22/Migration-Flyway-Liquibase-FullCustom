-- Constant (non-volatile) default: since PG11 the value is stored once in the catalog
-- (pg_attribute.attmissingval) and returned for all existing rows. No rewrite, instant,
-- even with NOT NULL.
ALTER TABLE customer ADD COLUMN status varchar(20) NOT NULL DEFAULT 'active';

INSERT INTO _demo_filenode VALUES ('2 after V2 (constant default)', pg_relation_filenode('customer'));

-- Demo helper: snapshot the catalog now (V3's rewrite materializes the value into every row
-- and clears attmissingval).
CREATE TABLE _demo_missing AS
SELECT attname::text, atthasmissing, attmissingval::text
FROM pg_attribute
WHERE attrelid = 'customer'::regclass AND attnum > 0 AND NOT attisdropped;

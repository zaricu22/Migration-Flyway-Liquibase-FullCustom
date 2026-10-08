-- Nullable column without a default: a catalog-only change. Existing rows are not touched,
-- they simply read the missing column as NULL. Instant, regardless of table size.
-- It still needs a short ACCESS EXCLUSIVE lock -> see A8 for the lock_timeout guard.
ALTER TABLE customer ADD COLUMN phone varchar(32);

INSERT INTO _demo_filenode VALUES ('after V2', pg_relation_filenode('customer'));

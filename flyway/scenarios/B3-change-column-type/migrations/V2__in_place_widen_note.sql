-- Not every type change needs expand/contract. These are catalog-only (no rewrite, no scan):
--   varchar(n) -> varchar(m) with m > n     varchar(n) -> text
--   numeric(p,s) -> numeric(p2,s), p2 > p   (same scale)
-- They still need a short ACCESS EXCLUSIVE lock, hence the lock_timeout.
SET LOCAL lock_timeout = '5s';
ALTER TABLE orders ALTER COLUMN note TYPE varchar(200);

INSERT INTO _demo_filenode VALUES ('2 after V2 (widen varchar)', pg_relation_filenode('orders'));

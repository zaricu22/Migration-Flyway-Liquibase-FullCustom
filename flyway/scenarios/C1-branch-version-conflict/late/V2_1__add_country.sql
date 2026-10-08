-- Developer C (long-running branch feature/country) picked version 2.1 when only V1 and V2 existed.
-- The branch is merged AFTER V3 is already applied in production: 2.1 < 3, so it's "out of order".
--
-- An out-of-order migration runs AFTER V3 on databases that already have V3, but BEFORE V3 on a
-- fresh database. So it must not depend on V3, and V3 must not depend on it.
ALTER TABLE customer ADD COLUMN country char(2);

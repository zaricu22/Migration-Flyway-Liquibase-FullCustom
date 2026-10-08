-- Step 2 of removal: the real drop, a release later.
-- No CASCADE: if something still depends on these objects, the migration should FAIL and
-- tell us, not silently drop a view or FK we forgot about.
SET LOCAL lock_timeout = '5s';

-- Metadata only, instant. The column's data stays in the rows until they're rewritten by
-- UPDATEs (or VACUUM FULL / pg_repack). Disk space isn't freed immediately.
ALTER TABLE customer DROP COLUMN legacy_code;

DROP TABLE _deprecated_customer_legacy_login;

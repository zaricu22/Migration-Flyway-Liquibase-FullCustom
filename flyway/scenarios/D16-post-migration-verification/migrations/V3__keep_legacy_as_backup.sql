-- Don't drop the source in the same release: rename it and drop it once the new tables have
-- been in production for a while (see B10). The verification function stays, too.
ALTER TABLE legacy_order_line RENAME TO _backup_legacy_order_line;

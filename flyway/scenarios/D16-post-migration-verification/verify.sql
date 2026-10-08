\echo '--- Migrated'
SELECT (SELECT count(*) FROM orders) AS orders, (SELECT count(*) FROM order_line) AS lines;

\echo '--- Re-run the verification against the backup of the source (inside a rolled-back transaction)'
BEGIN;
ALTER TABLE _backup_legacy_order_line RENAME TO legacy_order_line;
SELECT verify_order_migration();
ROLLBACK;

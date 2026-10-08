-- Before dropping anything: who depends on it, and is it still used? (run after V1)

\echo '--- Views that use customer.legacy_code'
SELECT DISTINCT v.relname AS dependent_view
FROM pg_depend d
JOIN pg_rewrite r   ON r.oid = d.objid
JOIN pg_class v     ON v.oid = r.ev_class
JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
WHERE d.refobjid = 'customer'::regclass
  AND a.attname = 'legacy_code'
  AND v.oid <> d.refobjid;

\echo '--- Foreign keys from/to customer_legacy_login'
SELECT conname, conrelid::regclass AS from_table, confrelid::regclass AS to_table
FROM pg_constraint
WHERE contype = 'f'
  AND (conrelid = 'customer_legacy_login'::regclass OR confrelid = 'customer_legacy_login'::regclass);

\echo '--- Is the table still used? Compare these counters over a few days (they only grow)'
SELECT relname, seq_scan, idx_scan, n_tup_ins, n_tup_upd, n_tup_del
FROM pg_stat_user_tables
WHERE schemaname = current_schema() AND relname = 'customer_legacy_login';

\echo '--- Dropping the column while the view needs it fails (good!)'
\set ON_ERROR_STOP off
BEGIN;
ALTER TABLE customer DROP COLUMN legacy_code;
ROLLBACK;
\echo '--- ...and DROP ... CASCADE would silently drop the view customer_export too. Avoid CASCADE in migrations.'

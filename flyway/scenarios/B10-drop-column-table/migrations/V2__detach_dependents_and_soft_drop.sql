-- Step 1 of removal. Precondition: the application no longer reads or writes legacy_code or
-- customer_legacy_login (deployed and verified BEFORE this migration).

-- 1. Detach dependents of the column: recreate the view without it.
--    CREATE OR REPLACE VIEW can only ADD columns, not remove them -> drop + create, in one transaction.
DROP VIEW customer_export;
CREATE VIEW customer_export AS
SELECT id, email FROM customer;

-- 2. Soft-drop the table: rename instead of drop. Any forgotten user (a cron job, a report,
--    another service) now fails loudly with "relation does not exist", but the data is still there
--    and the rename is instantly reversible. Wait a release cycle before the real drop (V3).
ALTER TABLE customer_legacy_login RENAME TO _deprecated_customer_legacy_login;

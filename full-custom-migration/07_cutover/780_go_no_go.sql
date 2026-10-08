-- CUTOVER step 4: GO / NO-GO. The last gate before the application is switched to the new system.
-- Every criterion is a check (phase 'cutover'); mig.gate prints them all and stops on any failure.
--   GO    -> switch the application (connection string / DNS), keep the old system frozen as a
--            read-only fallback for the agreed period, then ./run.sh cleanup
--   NO-GO -> ./run.sh unfreeze: the old system stays live; fix, rehearse, try again
\o /dev/null

SELECT mig.check('cutover', 'old system frozen (read-only for new sessions)', true,
    EXISTS (SELECT 1 FROM pg_db_role_setting s
            JOIN pg_database d ON d.oid = s.setdatabase
            WHERE d.datname = 'legacy_shop' AND s.setrole = 0
              AND 'default_transaction_read_only=on' = ANY (s.setconfig)));

SELECT mig.check('cutover', 'no change in the old system after the final delta', 0::bigint,
    (SELECT count(*) FROM src.customers
     WHERE updated_at > (SELECT extracted_until FROM mig.watermark WHERE entity = 'customers'))
    + (SELECT count(*) FROM src.order_lines
       WHERE updated_at > (SELECT extracted_until FROM mig.watermark WHERE entity = 'order_lines')));

SELECT mig.check('cutover', 'every earlier phase of this run DONE', 0::bigint,
    (SELECT count(*) FROM mig.run_phase
     WHERE run_id = mig.current_run() AND phase <> '07_go_no_go' AND status <> 'DONE'));

SELECT mig.check('cutover', 'every check of this run passed (validate, reconcile, verify, smoke)', 0::bigint,
    (SELECT count(*) FROM mig.reconciliation
     WHERE run_id = mig.current_run() AND NOT ok
       AND check_name NOT LIKE 'every check of this run%'));

SELECT mig.gate('cutover');
\o
\echo ''
\echo '>>> GO: switch the application to the new system. Keep the old one frozen as a read-only fallback.'

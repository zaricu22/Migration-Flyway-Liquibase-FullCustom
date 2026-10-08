-- The only phase that writes PRODUCTION. It refuses to start unless every earlier phase of this
-- run (including both gates) completed successfully.
\o /dev/null
SELECT mig.require_phase('02_validate');
SELECT mig.require_phase('03_transform');
SELECT mig.require_phase('04_reconcile');
\o

-- Large initial loads: this is the place to drop secondary indexes / disable user triggers on the
-- target and to raise maintenance_work_mem (see Flyway scenario D15). Not needed at demo size.

\echo 'Target before the load:'
SELECT 'customer' AS target_table, count(*) AS rows FROM public.customer
UNION ALL SELECT 'product', count(*) FROM public.product
UNION ALL SELECT 'orders', count(*) FROM public.orders
UNION ALL SELECT 'order_line', count(*) FROM public.order_line;

-- After the load: re-enable / rebuild what 500_pre_load removed (nothing at demo size), and refresh
-- the planner statistics: the tables went from empty to thousands of rows.
ANALYZE public.customer, public.address, public.category, public.product, public.orders, public.order_line;

\echo 'Target after the load:'
SELECT 'customer' AS target_table, count(*) AS rows FROM public.customer
UNION ALL SELECT 'address', count(*) FROM public.address
UNION ALL SELECT 'category', count(*) FROM public.category
UNION ALL SELECT 'product', count(*) FROM public.product
UNION ALL SELECT 'orders', count(*) FROM public.orders
UNION ALL SELECT 'order_line', count(*) FROM public.order_line;

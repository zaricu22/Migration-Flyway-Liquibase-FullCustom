-- Fresh statistics for the reconciliation and load joins (staging was just rebuilt).
ANALYZE stg.customer, stg.customer_alias, stg.address, stg.category, stg.product, stg.orders, stg.order_line;

SELECT 'customer' AS stg_table, count(*) AS rows FROM stg.customer
UNION ALL SELECT 'customer_alias', count(*) FROM stg.customer_alias
UNION ALL SELECT 'address', count(*) FROM stg.address
UNION ALL SELECT 'category', count(*) FROM stg.category
UNION ALL SELECT 'product', count(*) FROM stg.product
UNION ALL SELECT 'orders', count(*) FROM stg.orders
UNION ALL SELECT 'order_line', count(*) FROM stg.order_line;

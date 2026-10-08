SET NOCOUNT ON;
-- Expected: A 15.00 native (updated twice), B 25.00 loadUpdateData, C 30.00 loadUpdateData, D 40.00 native
SELECT sku, price, updated_by FROM product_price ORDER BY sku;

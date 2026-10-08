SET NOCOUNT ON;
SELECT * FROM customer_display ORDER BY id;
SELECT * FROM recent_customer ORDER BY id;
SELECT * FROM oldest_customers;
GO
-- || does not exist in SQL Server (string concat is +):
SELECT 'a' || 'b' AS pipes;
GO

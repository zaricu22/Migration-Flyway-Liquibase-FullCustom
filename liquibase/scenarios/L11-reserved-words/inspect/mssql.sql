SET NOCOUNT ON;
SELECT * FROM user_orders;
GO
-- Unquoted reserved word -> syntax error (GO: a compile error kills the whole batch)
SELECT * FROM user;
GO

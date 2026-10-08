SELECT * FROM user_orders;
-- "user" is not reserved in MySQL: the unquoted name works here (and nowhere else)
SELECT * FROM user;
-- "order" is reserved: unquoted -> syntax error
SELECT * FROM order;

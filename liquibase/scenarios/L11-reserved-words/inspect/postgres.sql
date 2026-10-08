SELECT * FROM user_orders;
\echo 'Unquoted "user" is NOT an error in PostgreSQL: it is the CURRENT_USER function. Wrong data, silently:'
SELECT * FROM user;
\echo 'Quoted: the table'
SELECT * FROM "user";

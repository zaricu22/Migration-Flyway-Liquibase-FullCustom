-- OLD application: writes float "amount". Works until V5.
\echo '--- app v1'
INSERT INTO orders (note, amount) VALUES ('app v1', 10.1 + 0.2);
SELECT * FROM orders ORDER BY id DESC LIMIT 2;

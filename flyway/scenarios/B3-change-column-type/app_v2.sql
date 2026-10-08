-- NEW application: writes exact "total_amount". Works from V4 on.
\echo '--- app v2'
INSERT INTO orders (note, total_amount) VALUES ('app v2', 10.30);
SELECT * FROM orders ORDER BY id DESC LIMIT 2;

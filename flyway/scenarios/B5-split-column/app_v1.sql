-- OLD application: full_name only. Works until V4.
\echo '--- app v1'
INSERT INTO customer (full_name) VALUES ('Grace Brewster Hopper');
SELECT * FROM customer WHERE id <= 4 OR id = (SELECT max(id) FROM customer) ORDER BY id;

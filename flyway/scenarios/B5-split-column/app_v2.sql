-- NEW application: first_name / last_name. Works from V3 on.
\echo '--- app v2'
INSERT INTO customer (first_name, last_name) VALUES ('Margaret', 'Hamilton');
SELECT * FROM customer WHERE id <= 4 OR id = (SELECT max(id) FROM customer) ORDER BY id;

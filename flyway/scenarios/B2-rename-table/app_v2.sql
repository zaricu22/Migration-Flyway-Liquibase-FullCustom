-- NEW application: uses table "product". Works after V2.
\echo '--- app v2: insert / select on product'
INSERT INTO product (name, price) VALUES ('Inserted by app v2', 19.99);
SELECT id, name, price FROM product ORDER BY id DESC LIMIT 3;

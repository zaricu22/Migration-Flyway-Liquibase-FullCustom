-- NEW application: category_id + JOIN. Works from V3 on.
\echo '--- app v2'
INSERT INTO product (name, category_id)
SELECT 'New app laptop', id FROM category WHERE lower(name) = 'electronics';

SELECT c.name AS category, count(*) AS products
FROM product p LEFT JOIN category c ON c.id = p.category_id
GROUP BY c.name ORDER BY c.name;

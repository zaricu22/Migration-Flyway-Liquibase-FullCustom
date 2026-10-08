-- OLD application: free-text category. Works until V4.
\echo '--- app v1: existing category in odd spelling + a brand-new category'
INSERT INTO product (name, category) VALUES ('Old app book', '  BoOkS'), ('Old app rake', 'Garden Tools');
SELECT p.id, p.name, p.category, p.category_id, c.name AS resolved
FROM product p LEFT JOIN category c ON c.id = p.category_id
ORDER BY p.id DESC LIMIT 2;

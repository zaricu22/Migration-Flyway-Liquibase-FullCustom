\echo '--- Categories (one per normalized name, most common spelling)'
SELECT c.id, c.name, count(p.id) AS products
FROM category c LEFT JOIN product p ON p.category_id = c.id
GROUP BY c.id, c.name ORDER BY c.id;

DO $$
BEGIN
    IF (SELECT count(*) FROM category WHERE lower(name) IN ('books', 'electronics', 'home & garden')) <> 3 THEN
        RAISE EXCEPTION 'FAIL: spellings were not merged into 3 categories';
    END IF;
    IF (SELECT name FROM category WHERE lower(name) = 'books') <> 'Books' THEN
        RAISE EXCEPTION 'FAIL: display name is not the most common spelling';
    END IF;
    IF (SELECT count(*) FROM product WHERE category_id IS NULL) <> 2500 THEN
        RAISE EXCEPTION 'FAIL: expected exactly the 2500 products that had no category to stay NULL';
    END IF;
    RAISE NOTICE 'OK: free text normalized into a lookup table';
END $$;

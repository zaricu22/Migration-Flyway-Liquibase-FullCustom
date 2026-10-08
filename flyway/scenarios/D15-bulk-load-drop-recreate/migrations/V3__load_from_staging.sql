-- The constraints are gone, so the checks they would have done must happen BEFORE the load:
-- once V3 commits, a bad row can only be found by V4 failing, with the data already in.
DO $$
DECLARE
    bad_fk   bigint;
    dup_sku  bigint;
BEGIN
    SELECT count(*) INTO bad_fk FROM product_import i
    WHERE NOT EXISTS (SELECT 1 FROM category c WHERE c.id = i.category_id);

    SELECT count(*) INTO dup_sku FROM (
        SELECT sku FROM product_import GROUP BY sku HAVING count(*) > 1
        UNION ALL
        SELECT i.sku FROM product_import i JOIN product p ON p.sku = i.sku
    ) d;

    IF bad_fk > 0 OR dup_sku > 0 THEN
        RAISE EXCEPTION 'Import rejected: % rows with unknown category, % duplicate SKUs', bad_fk, dup_sku;
    END IF;
END $$;

-- The disabled trigger would have set updated_at: set it explicitly.
INSERT INTO product (sku, name, category_id, price, updated_at)
SELECT sku, name, category_id, price, now()
FROM product_import;

-- EXPAND: the lookup table, filled from the distinct values, plus the new FK column.
CREATE TABLE category (
    id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name varchar(100) NOT NULL
);
-- Uniqueness on the NORMALIZED name: 'Books' and ' books' are the same category.
CREATE UNIQUE INDEX category_name_normalized_uq ON category (lower(trim(name)));

-- Group spellings by the normalized key. The display name is the MOST COMMON original spelling
-- (mode()), so 'Books' wins over 'BOOKS' and ' books'.
INSERT INTO category (name)
SELECT mode() WITHIN GROUP (ORDER BY trim(category))
FROM product
WHERE category IS NOT NULL AND trim(category) <> ''
GROUP BY lower(trim(category))
ORDER BY 1;

ALTER TABLE product ADD COLUMN category_id bigint REFERENCES category (id);
CREATE INDEX product_category_id_idx ON product (category_id);

-- App v1 keeps writing free text: resolve it to a category, creating unknown ones on the fly.
CREATE FUNCTION product_resolve_category() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.category IS NULL OR trim(NEW.category) = '' THEN
        RETURN NEW;
    END IF;
    IF TG_OP = 'INSERT' OR NEW.category IS DISTINCT FROM OLD.category THEN
        INSERT INTO category (name) VALUES (trim(NEW.category))
        ON CONFLICT (lower(trim(name))) DO NOTHING;

        SELECT id INTO NEW.category_id
        FROM category WHERE lower(trim(name)) = lower(trim(NEW.category));
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER product_resolve_category
    BEFORE INSERT OR UPDATE OF category ON product
    FOR EACH ROW EXECUTE FUNCTION product_resolve_category();

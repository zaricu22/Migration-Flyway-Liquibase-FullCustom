-- category is free text typed by humans: same category, many spellings.
-- Goal: a category lookup table + product.category_id FK.
CREATE TABLE product (
    id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name     varchar(200) NOT NULL,
    category varchar(100)
);

INSERT INTO product (name, category)
SELECT 'Product ' || g,
       (ARRAY['Books', 'Books', 'Books', ' books', 'BOOKS',
              'Electronics', 'Electronics', 'electronics ',
              'Home & Garden', 'Home & Garden', 'home & garden',
              NULL])[1 + g % 12]
FROM generate_series(1, 30000) AS g;

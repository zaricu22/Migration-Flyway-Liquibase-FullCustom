-- Products + categories.
-- Category is free text ('Books', ' books', 'BOOKS'): group by the normalized value and use the
-- MOST COMMON original spelling as the display name (the lookup table in the target).
WITH spelling AS (
    SELECT lower(btrim(category)) AS norm_key,
           mode() WITHIN GROUP (ORDER BY btrim(category)) AS display_name
    FROM raw.v_products
    GROUP BY lower(btrim(category))
)
INSERT INTO stg.category (name)
SELECT display_name FROM spelling;

INSERT INTO stg.product (sku, title, category_name, price_cents)
SELECT p.sku,
       btrim(p.title),
       c.name,
       mig.parse_amount_cents(p.price)
FROM raw.v_products p
JOIN stg.category c ON lower(c.name) = lower(btrim(p.category))
WHERE NOT EXISTS (SELECT 1 FROM mig.v_rejected r WHERE r.entity = 'product' AND r.source_key = p.sku);

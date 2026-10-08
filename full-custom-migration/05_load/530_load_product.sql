-- Categories first (parent), then products (child). Both upserts, both recorded in the id map.
INSERT INTO public.category (name)
SELECT name FROM stg.category
ON CONFLICT (name) DO NOTHING;

INSERT INTO mig.id_map (entity, legacy_key, new_id, run_id)
SELECT 'category', c.name, c.id, mig.current_run()
FROM public.category c JOIN stg.category s ON s.name = c.name
ON CONFLICT (entity, legacy_key) DO NOTHING;

INSERT INTO public.product (sku, title, category_id, price_cents)
SELECT p.sku, p.title, c.id, p.price_cents
FROM stg.product p
JOIN public.category c ON c.name = p.category_name
ON CONFLICT (sku) DO UPDATE
    SET title = EXCLUDED.title, category_id = EXCLUDED.category_id, price_cents = EXCLUDED.price_cents
    WHERE (product.title, product.category_id, product.price_cents)
          IS DISTINCT FROM (EXCLUDED.title, EXCLUDED.category_id, EXCLUDED.price_cents);

INSERT INTO mig.id_map (entity, legacy_key, new_id, run_id)
SELECT 'product', p.sku, p.id, mig.current_run()
FROM public.product p JOIN stg.product s ON s.sku = p.sku
ON CONFLICT (entity, legacy_key) DO NOTHING;

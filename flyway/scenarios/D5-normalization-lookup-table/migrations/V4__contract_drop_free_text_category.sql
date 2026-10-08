SET LOCAL lock_timeout = '5s';

DROP TRIGGER product_resolve_category ON product;
DROP FUNCTION product_resolve_category();
ALTER TABLE product DROP COLUMN category;

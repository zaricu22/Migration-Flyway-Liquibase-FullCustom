-- product has everything a real table has: PK, unique key, secondary indexes, a FK and a trigger.
-- A 400,000-row import is waiting in a staging table (e.g. loaded with COPY from a CSV).
CREATE TABLE category (
    id   int PRIMARY KEY,
    name varchar(100) NOT NULL
);
INSERT INTO category SELECT g, 'Category ' || g FROM generate_series(1, 50) AS g;

CREATE TABLE product (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku         varchar(30)   NOT NULL,
    name        varchar(200)  NOT NULL,
    category_id int           NOT NULL,
    price       numeric(12,2) NOT NULL,
    updated_at  timestamptz   NOT NULL
);
CREATE UNIQUE INDEX product_sku_uq       ON product (sku);
CREATE INDEX        product_name_idx     ON product (name);
CREATE INDEX        product_category_idx ON product (category_id);
ALTER TABLE product ADD CONSTRAINT product_category_fk FOREIGN KEY (category_id) REFERENCES category (id);

CREATE FUNCTION product_touch_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END $$;
CREATE TRIGGER product_touch_updated_at
    BEFORE INSERT OR UPDATE ON product
    FOR EACH ROW EXECUTE FUNCTION product_touch_updated_at();

INSERT INTO product (sku, name, category_id, price, updated_at)
SELECT 'OLD-' || g, 'Existing product ' || g, 1 + g % 50, 9.99, now()
FROM generate_series(1, 50000) AS g;

CREATE TABLE product_import (
    sku         varchar(30),
    name        varchar(200),
    category_id int,
    price       numeric(12,2)
);
INSERT INTO product_import
SELECT 'IMP-' || g, md5(g::text), 1 + g % 50, (g % 10000) / 100.0 + 1
FROM generate_series(1, 400000) AS g;

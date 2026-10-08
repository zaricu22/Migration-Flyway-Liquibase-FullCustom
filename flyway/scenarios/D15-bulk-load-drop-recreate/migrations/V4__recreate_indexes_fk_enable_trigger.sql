-- More memory for index builds = fewer sort passes to disk. SET LOCAL: this migration only.
SET LOCAL maintenance_work_mem = '256MB';

CREATE UNIQUE INDEX product_sku_uq       ON product (sku);
CREATE INDEX        product_name_idx     ON product (name);
CREATE INDEX        product_category_idx ON product (category_id);

-- NOT VALID + VALIDATE: same result as a plain ADD, but the check of existing rows runs with the
-- weaker lock. That matters if this runs while the application is back online.
ALTER TABLE product ADD CONSTRAINT product_category_fk
    FOREIGN KEY (category_id) REFERENCES category (id) NOT VALID;
ALTER TABLE product VALIDATE CONSTRAINT product_category_fk;

ALTER TABLE product ENABLE TRIGGER product_touch_updated_at;

-- The table grew 9x: refresh planner statistics now instead of waiting for autovacuum.
ANALYZE product;

DROP TABLE product_import;

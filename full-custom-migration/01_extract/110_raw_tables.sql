-- RAW layer: an exact, untyped copy of the source. Everything is text, so the extract can never
-- fail on dirty values: problems are found and reported by validation, not by a crashing INSERT.
-- Every row carries batch metadata: which run brought it, and when.
-- _deleted marks a TOMBSTONE: the delta found the key no longer exists in the source (710_delta_sync).
CREATE TABLE IF NOT EXISTS raw.customers (
    cust_no text, full_name text, email text, phone text, address text,
    country text, created text, active text, updated_at text,
    _batch_id  bigint      NOT NULL,
    _loaded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    _deleted   boolean     NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS raw.products (
    sku text, title text, price text, category text,
    _batch_id  bigint      NOT NULL,
    _loaded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    _deleted   boolean     NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS raw.order_lines (
    order_no text, line_no text, cust_no text, order_date text, status_code text,
    sku text, qty text, unit_price text, updated_at text,
    _batch_id  bigint      NOT NULL,
    _loaded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    _deleted   boolean     NOT NULL DEFAULT false
);

-- raw tables created before delete detection existed get the column too
ALTER TABLE raw.customers   ADD COLUMN IF NOT EXISTS _deleted boolean NOT NULL DEFAULT false;
ALTER TABLE raw.products    ADD COLUMN IF NOT EXISTS _deleted boolean NOT NULL DEFAULT false;
ALTER TABLE raw.order_lines ADD COLUMN IF NOT EXISTS _deleted boolean NOT NULL DEFAULT false;

-- raw keeps EVERY version that was extracted (full load + each delta). The rest of the pipeline
-- works on the LATEST version per source key, and a key whose latest version is a tombstone is gone.
CREATE OR REPLACE VIEW raw.v_customers AS
SELECT * FROM (SELECT DISTINCT ON (cust_no) * FROM raw.customers ORDER BY cust_no, _batch_id DESC) latest
WHERE NOT _deleted;

CREATE OR REPLACE VIEW raw.v_products AS
SELECT * FROM (SELECT DISTINCT ON (sku) * FROM raw.products ORDER BY sku, _batch_id DESC) latest
WHERE NOT _deleted;

CREATE OR REPLACE VIEW raw.v_order_lines AS
SELECT * FROM (SELECT DISTINCT ON (order_no, line_no) * FROM raw.order_lines ORDER BY order_no, line_no, _batch_id DESC) latest
WHERE NOT _deleted;

-- Keys deleted in the source (latest version = tombstone). Used by 05_load/560 and 06_verify/640.
CREATE OR REPLACE VIEW raw.v_deleted_customers AS
SELECT cust_no FROM (SELECT DISTINCT ON (cust_no) cust_no, _deleted FROM raw.customers ORDER BY cust_no, _batch_id DESC) latest
WHERE _deleted;

CREATE OR REPLACE VIEW raw.v_deleted_products AS
SELECT sku FROM (SELECT DISTINCT ON (sku) sku, _deleted FROM raw.products ORDER BY sku, _batch_id DESC) latest
WHERE _deleted;

CREATE OR REPLACE VIEW raw.v_deleted_order_lines AS
SELECT order_no, line_no FROM (SELECT DISTINCT ON (order_no, line_no) order_no, line_no, _deleted
                               FROM raw.order_lines ORDER BY order_no, line_no, _batch_id DESC) latest
WHERE _deleted;

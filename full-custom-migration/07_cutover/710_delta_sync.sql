-- INCREMENTAL (delta) extract: only what changed in the old system since the last extract.
-- Used between the initial load and the final switch: the old system keeps running, the delta runs
-- repeatedly, and at cutover (./run.sh cutover) a freeze + one last delta brings the new system up to date.
-- ./run.sh delta: apply source/legacy_changes.sql -> this file -> validate .. verify again.
--
-- The new versions land in raw with this run's batch id; raw.v_* views pick the latest version per
-- key, so validation/transformation see the current state of every record. Loads are upserts.
--
-- Three ways to find changes, depending on what the source offers:
--   1. CHANGED rows:  updated_at > watermark        (customers, order_lines)
--   2. CHANGED rows of a table WITHOUT updated_at: compare the content with raw   (products)
--   3. DELETED rows:  full KEY comparison source <-> raw, a missing key becomes a tombstone
-- 2 and 3 read every key (or row) of the source on every delta: fine here, expensive at volume
-- (then: soft-delete flags in the source, a key-only extract, or CDC).

-- 1. changed rows by timestamp ------------------------------------------------------------------
INSERT INTO raw.customers (cust_no, full_name, email, phone, address, country, created, active, updated_at, _batch_id)
SELECT cust_no::text, full_name, email, phone, address, country, created, active::text, updated_at::text, mig.current_run()
FROM src.customers
WHERE updated_at > (SELECT extracted_until FROM mig.watermark WHERE entity = 'customers');

INSERT INTO raw.order_lines (order_no, line_no, cust_no, order_date, status_code, sku, qty, unit_price, updated_at, _batch_id)
SELECT order_no, line_no::text, cust_no::text, order_date, status_code, sku, qty, unit_price, updated_at::text, mig.current_run()
FROM src.order_lines
WHERE updated_at > (SELECT extracted_until FROM mig.watermark WHERE entity = 'order_lines');

-- 2. products have no updated_at: new or different content compared with the latest raw version
INSERT INTO raw.products (sku, title, price, category, _batch_id)
SELECT s.sku, s.title, s.price, s.category, mig.current_run()
FROM src.products s
LEFT JOIN raw.v_products r ON r.sku = s.sku
WHERE r.sku IS NULL
   OR (s.title, s.price, s.category) IS DISTINCT FROM (r.title, r.price, r.category);

-- 3. deleted rows: keys that are still live in raw but no longer exist in the source -> tombstone
--    (a copy of the last known version with _deleted = true; the raw.v_* views then hide the key)
INSERT INTO raw.customers (cust_no, full_name, email, phone, address, country, created, active, updated_at, _batch_id, _deleted)
SELECT r.cust_no, r.full_name, r.email, r.phone, r.address, r.country, r.created, r.active, r.updated_at, mig.current_run(), true
FROM raw.v_customers r
WHERE NOT EXISTS (SELECT 1 FROM src.customers s WHERE s.cust_no::text = r.cust_no);

INSERT INTO raw.products (sku, title, price, category, _batch_id, _deleted)
SELECT r.sku, r.title, r.price, r.category, mig.current_run(), true
FROM raw.v_products r
WHERE NOT EXISTS (SELECT 1 FROM src.products s WHERE s.sku = r.sku);

INSERT INTO raw.order_lines (order_no, line_no, cust_no, order_date, status_code, sku, qty, unit_price, updated_at, _batch_id, _deleted)
SELECT r.order_no, r.line_no, r.cust_no, r.order_date, r.status_code, r.sku, r.qty, r.unit_price, r.updated_at, mig.current_run(), true
FROM raw.v_order_lines r
WHERE NOT EXISTS (SELECT 1 FROM src.order_lines s WHERE s.order_no = r.order_no AND s.line_no::text = r.line_no);

-- move the high-water marks (same snapshot: this file is one transaction)
UPDATE mig.watermark w
SET extracted_until = greatest(w.extracted_until, s.max_updated)
FROM (SELECT 'customers' AS entity, max(updated_at) AS max_updated FROM src.customers
      UNION ALL
      SELECT 'order_lines', max(updated_at) FROM src.order_lines) s
WHERE w.entity = s.entity;

\echo 'Rows brought in by this delta:'
SELECT 'customers' AS raw_table,
       count(*) FILTER (WHERE NOT _deleted) AS changed, count(*) FILTER (WHERE _deleted) AS deleted
FROM raw.customers WHERE _batch_id = mig.current_run()
UNION ALL
SELECT 'products', count(*) FILTER (WHERE NOT _deleted), count(*) FILTER (WHERE _deleted)
FROM raw.products WHERE _batch_id = mig.current_run()
UNION ALL
SELECT 'order_lines', count(*) FILTER (WHERE NOT _deleted), count(*) FILTER (WHERE _deleted)
FROM raw.order_lines WHERE _batch_id = mig.current_run();

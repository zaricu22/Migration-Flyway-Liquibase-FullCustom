-- FULL extract: copy the whole source 1:1 into raw (only the first time; later changes come in
-- through the incremental extract, 07_cutover/710_delta_sync.sql).
-- The file runs in ONE transaction, and postgres_fdw reads the source in one remote transaction:
-- all three tables come from the same consistent snapshot of the old system.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM raw.customers WHERE _batch_id <> mig.current_run()) THEN
        RAISE NOTICE 'raw already contains a full extract from an earlier run: skipped (use ./run.sh delta for changes)';
        RETURN;
    END IF;

    -- re-running this phase in the same run replaces its own batch
    DELETE FROM raw.customers   WHERE _batch_id = mig.current_run();
    DELETE FROM raw.products    WHERE _batch_id = mig.current_run();
    DELETE FROM raw.order_lines WHERE _batch_id = mig.current_run();

    INSERT INTO raw.customers (cust_no, full_name, email, phone, address, country, created, active, updated_at, _batch_id)
    SELECT cust_no::text, full_name, email, phone, address, country, created, active::text, updated_at::text, mig.current_run()
    FROM src.customers;

    INSERT INTO raw.products (sku, title, price, category, _batch_id)
    SELECT sku, title, price, category, mig.current_run()
    FROM src.products;

    INSERT INTO raw.order_lines (order_no, line_no, cust_no, order_date, status_code, sku, qty, unit_price, updated_at, _batch_id)
    SELECT order_no, line_no::text, cust_no::text, order_date, status_code, sku, qty, unit_price, updated_at::text, mig.current_run()
    FROM src.order_lines;

    -- high-water marks for the next (delta) extract, from the same snapshot
    INSERT INTO mig.watermark (entity, extracted_until) VALUES
        ('customers',   (SELECT max(updated_at) FROM src.customers)),
        ('order_lines', (SELECT max(updated_at) FROM src.order_lines))
    ON CONFLICT (entity) DO UPDATE SET extracted_until = EXCLUDED.extracted_until;
END $$;

SELECT 'customers' AS raw_table, count(*) AS rows FROM raw.customers WHERE _batch_id = mig.current_run()
UNION ALL SELECT 'products', count(*) FROM raw.products WHERE _batch_id = mig.current_run()
UNION ALL SELECT 'order_lines', count(*) FROM raw.order_lines WHERE _batch_id = mig.current_run();

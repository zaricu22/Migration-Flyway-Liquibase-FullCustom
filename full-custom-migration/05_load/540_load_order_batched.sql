-- Orders + lines: the biggest table, so it's loaded in BATCHES with a CHECKPOINT.
-- "_batched" in the file name tells run.sh to run it WITHOUT a wrapping transaction, so the
-- procedure can COMMIT after every batch. If the load is killed, the next run of this phase
-- resumes after the last committed batch (checkpoint per run), and the upserts make overlaps harmless.
CREATE OR REPLACE PROCEDURE mig.load_orders(p_batch_size int DEFAULT 1000)
LANGUAGE plpgsql AS $$
DECLARE
    v_job     text := 'load_orders:run' || mig.current_run();
    v_last    text;
    v_upto    text;
    v_batches int := 0;
BEGIN
    INSERT INTO mig.checkpoint (job, last_key) VALUES (v_job, '') ON CONFLICT (job) DO NOTHING;
    SELECT last_key INTO v_last FROM mig.checkpoint WHERE job = v_job;
    IF v_last <> '' THEN
        RAISE NOTICE 'resuming after order %', v_last;
    END IF;
    COMMIT;

    LOOP
        -- next key range: (v_last, v_upto]
        SELECT max(order_no) INTO v_upto
        FROM (SELECT order_no FROM stg.orders WHERE order_no > v_last ORDER BY order_no LIMIT p_batch_size) b;
        EXIT WHEN v_upto IS NULL;

        INSERT INTO public.orders (order_no, customer_id, order_date, status)
        SELECT o.order_no, m.new_id, o.order_date, o.status
        FROM stg.orders o
        JOIN mig.id_map m ON m.entity = 'customer' AND m.legacy_key = o.legacy_cust_no::text
        WHERE o.order_no > v_last AND o.order_no <= v_upto
        ON CONFLICT (order_no) DO UPDATE
            SET customer_id = EXCLUDED.customer_id, order_date = EXCLUDED.order_date, status = EXCLUDED.status
            WHERE (orders.customer_id, orders.order_date, orders.status)
                  IS DISTINCT FROM (EXCLUDED.customer_id, EXCLUDED.order_date, EXCLUDED.status);

        INSERT INTO public.order_line (order_id, line_no, product_id, qty, unit_price_cents)
        SELECT t.id, l.line_no, p.id, l.qty, l.unit_price_cents
        FROM stg.order_line l
        JOIN public.orders  t ON t.order_no = l.order_no
        JOIN public.product p ON p.sku = l.sku
        WHERE l.order_no > v_last AND l.order_no <= v_upto
        ON CONFLICT (order_id, line_no) DO UPDATE
            SET product_id = EXCLUDED.product_id, qty = EXCLUDED.qty, unit_price_cents = EXCLUDED.unit_price_cents
            WHERE (order_line.product_id, order_line.qty, order_line.unit_price_cents)
                  IS DISTINCT FROM (EXCLUDED.product_id, EXCLUDED.qty, EXCLUDED.unit_price_cents);

        INSERT INTO mig.id_map (entity, legacy_key, new_id, run_id)
        SELECT 'order', t.order_no, t.id, mig.current_run()
        FROM public.orders t
        JOIN stg.orders o ON o.order_no = t.order_no
        WHERE t.order_no > v_last AND t.order_no <= v_upto
        ON CONFLICT (entity, legacy_key) DO NOTHING;

        -- batch data and checkpoint commit TOGETHER
        UPDATE mig.checkpoint SET last_key = v_upto, updated_at = clock_timestamp() WHERE job = v_job;
        COMMIT;

        v_last := v_upto;
        v_batches := v_batches + 1;
    END LOOP;

    RAISE NOTICE 'orders loaded in % batch(es) of up to % orders', v_batches, p_batch_size;
END $$;

CALL mig.load_orders(1000);

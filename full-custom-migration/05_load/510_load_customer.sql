-- Customers: UPSERT keyed by the legacy number, so the same load can run again (delta runs,
-- reruns after a failure) without duplicating anything. Unchanged rows are not rewritten.
INSERT INTO public.customer (email, first_name, last_name, phone, country_code, created_on, active, legacy_cust_no)
SELECT email, first_name, last_name, phone, country_code, created_on, active, legacy_cust_no
FROM stg.customer
ON CONFLICT (legacy_cust_no) DO UPDATE
    SET email = EXCLUDED.email, first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name,
        phone = EXCLUDED.phone, country_code = EXCLUDED.country_code,
        created_on = EXCLUDED.created_on, active = EXCLUDED.active
    WHERE (customer.email, customer.first_name, customer.last_name, customer.phone,
           customer.country_code, customer.created_on, customer.active)
          IS DISTINCT FROM
          (EXCLUDED.email, EXCLUDED.first_name, EXCLUDED.last_name, EXCLUDED.phone,
           EXCLUDED.country_code, EXCLUDED.created_on, EXCLUDED.active);

-- id map: EVERY accepted legacy number (survivors and merged duplicates) -> the new customer id.
INSERT INTO mig.id_map (entity, legacy_key, new_id, run_id)
SELECT 'customer', a.legacy_cust_no::text, c.id, mig.current_run()
FROM stg.customer_alias a
JOIN public.customer c ON c.legacy_cust_no = a.survivor_cust_no
ON CONFLICT (entity, legacy_key) DO UPDATE
    SET new_id = EXCLUDED.new_id, run_id = EXCLUDED.run_id
    WHERE mig.id_map.new_id <> EXCLUDED.new_id;

-- Addresses: the foreign key (customer_id) is resolved through mig.id_map, never by guessing.
INSERT INTO public.address (customer_id, street, zip, city)
SELECT m.new_id, a.street, a.zip, a.city
FROM stg.address a
JOIN mig.id_map m ON m.entity = 'customer' AND m.legacy_key = a.legacy_cust_no::text
ON CONFLICT (customer_id) DO UPDATE
    SET street = EXCLUDED.street, zip = EXCLUDED.zip, city = EXCLUDED.city
    WHERE (address.street, address.zip, address.city) IS DISTINCT FROM (EXCLUDED.street, EXCLUDED.zip, EXCLUDED.city);

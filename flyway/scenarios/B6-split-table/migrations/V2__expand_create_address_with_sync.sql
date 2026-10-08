-- EXPAND: new table + sync triggers in BOTH directions:
--   app v1 writes customer.street/city/zip  -> copied into address
--   app v2 writes address                   -> copied back into customer
-- Two triggers that update each other's table would loop forever. Two guards prevent that:
--   * pg_trigger_depth() > 1  -> we are inside the other trigger, stop
--   * IS DISTINCT FROM        -> nothing changed, don't write
CREATE TABLE address (
    customer_id bigint PRIMARY KEY REFERENCES customer (id) ON DELETE CASCADE,
    street      varchar(200),
    city        varchar(100),
    zip         varchar(20)
);

-- If we first update customer table, it will call trigger to update address table, which will also call trigger to update customer table.
-- To avoid infinite loop, we check pg_trigger_depth() > 1 and skip the update if we are already inside a trigger.
CREATE FUNCTION customer_to_address() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF pg_trigger_depth() > 1 THEN RETURN NULL; END IF; -- update only once (skip when other trigger updates customer)
    IF NEW.street IS NULL AND NEW.city IS NULL AND NEW.zip IS NULL THEN RETURN NULL; END IF;

    INSERT INTO address (customer_id, street, city, zip) -- if not exist in address table
    VALUES (NEW.id, NEW.street, NEW.city, NEW.zip)
    ON CONFLICT (customer_id) DO UPDATE  -- if exist in address table
        SET street = EXCLUDED.street, city = EXCLUDED.city, zip = EXCLUDED.zip
        WHERE (address.street, address.city, address.zip) IS DISTINCT FROM (EXCLUDED.street, EXCLUDED.city, EXCLUDED.zip); -- <> returns NULL when the only difference involves a NULL
    RETURN NULL;
END $$;

CREATE TRIGGER customer_to_address
    AFTER INSERT OR UPDATE OF street, city, zip ON customer
    FOR EACH ROW EXECUTE FUNCTION customer_to_address();

-- If we first update address table, it will call trigger to update customer table, which will also call trigger to update address table.
-- To avoid infinite loop, we check pg_trigger_depth() > 1 and skip the update if we are already inside a trigger.
CREATE FUNCTION address_to_customer() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF pg_trigger_depth() > 1 THEN RETURN NULL; END IF; -- update only once (skip the other trigger's update)

    UPDATE customer -- we must also update customer table
    SET street = NEW.street, city = NEW.city, zip = NEW.zip
    WHERE id = NEW.customer_id AND (street, city, zip) IS DISTINCT FROM (NEW.street, NEW.city, NEW.zip); -- <> returns NULL when the only difference involves a NULL
    RETURN NULL;
END $$;

CREATE TRIGGER address_to_customer
    AFTER INSERT OR UPDATE ON address
    FOR EACH ROW EXECUTE FUNCTION address_to_customer();

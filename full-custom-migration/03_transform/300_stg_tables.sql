-- STAGING layer: typed, cleansed rows in (almost) the target shape, still keyed by the LEGACY keys.
-- Staging is rebuilt from scratch on every run (TRUNCATE): a transformation must never depend on
-- the result of a previous run. Fix a rule -> rerun transform -> same input, new correct output.
CREATE TABLE IF NOT EXISTS stg.customer (
    legacy_cust_no int PRIMARY KEY,          -- the SURVIVOR of each duplicate group
    email          text NOT NULL UNIQUE,
    first_name     text NOT NULL,
    last_name      text,
    phone          text,
    country_code   char(2) NOT NULL,
    created_on     date NOT NULL,
    active         boolean NOT NULL
);

-- Every accepted legacy customer number -> the survivor it was merged into
-- (survivors map to themselves). Orders of duplicates follow this mapping.
CREATE TABLE IF NOT EXISTS stg.customer_alias (
    legacy_cust_no   int PRIMARY KEY,
    survivor_cust_no int NOT NULL
);

CREATE TABLE IF NOT EXISTS stg.address (
    legacy_cust_no int PRIMARY KEY,
    street text NOT NULL,
    zip    text NOT NULL,
    city   text NOT NULL
);

CREATE TABLE IF NOT EXISTS stg.category (
    name text PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS stg.product (
    sku           text PRIMARY KEY,
    title         text NOT NULL,
    category_name text NOT NULL,
    price_cents   bigint NOT NULL
);

CREATE TABLE IF NOT EXISTS stg.orders (
    order_no       text PRIMARY KEY,
    legacy_cust_no int  NOT NULL,             -- already resolved to the survivor
    order_date     date NOT NULL,
    status         text NOT NULL
);

CREATE TABLE IF NOT EXISTS stg.order_line (
    order_no         text NOT NULL,
    line_no          int  NOT NULL,
    sku              text NOT NULL,
    qty              int  NOT NULL,
    unit_price_cents bigint NOT NULL,
    PRIMARY KEY (order_no, line_no)
);

TRUNCATE stg.customer, stg.customer_alias, stg.address, stg.category, stg.product, stg.orders, stg.order_line;

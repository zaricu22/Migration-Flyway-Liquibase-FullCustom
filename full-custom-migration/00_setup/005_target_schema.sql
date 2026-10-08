-- The NEW (target) model in schema public. In a real project this schema is owned by the
-- application's schema migrations (Flyway / Liquibase); it's here so the demo is self-contained.
-- Note what the target enforces: the dirty data from the old system could not be inserted as-is.
CREATE TABLE IF NOT EXISTS public.country (
    code char(2)      PRIMARY KEY,
    name varchar(100) NOT NULL
);
INSERT INTO public.country (code, name) VALUES ('RS', 'Serbia'), ('DE', 'Germany'), ('FR', 'France')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.customer (
    id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email          varchar(255) NOT NULL UNIQUE,
    first_name     varchar(100) NOT NULL,
    last_name      varchar(100),
    phone          varchar(20)  CHECK (phone ~ '^\+[1-9][0-9]{7,14}$'),
    country_code   char(2)      NOT NULL REFERENCES public.country,
    created_on     date         NOT NULL,
    active         boolean      NOT NULL,
    legacy_cust_no int          UNIQUE          -- traceability back to the old system
);

CREATE TABLE IF NOT EXISTS public.address (
    customer_id bigint PRIMARY KEY REFERENCES public.customer ON DELETE CASCADE,
    street      varchar(200) NOT NULL,
    zip         varchar(10)  NOT NULL,
    city        varchar(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.category (
    id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name varchar(100) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS public.product (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku         varchar(20)  NOT NULL UNIQUE,
    title       varchar(200) NOT NULL,
    category_id bigint       NOT NULL REFERENCES public.category,
    price_cents bigint       NOT NULL CHECK (price_cents > 0)
);

CREATE TABLE IF NOT EXISTS public.orders (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_no    varchar(20) NOT NULL UNIQUE,
    customer_id bigint      NOT NULL REFERENCES public.customer,
    order_date  date        NOT NULL,
    status      varchar(20) NOT NULL CHECK (status IN ('new', 'paid', 'shipped', 'cancelled'))
);
CREATE INDEX IF NOT EXISTS orders_customer_id_idx ON public.orders (customer_id);

CREATE TABLE IF NOT EXISTS public.order_line (
    id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id         bigint NOT NULL REFERENCES public.orders ON DELETE CASCADE,
    line_no          int    NOT NULL,
    product_id       bigint NOT NULL REFERENCES public.product,
    qty              int    NOT NULL CHECK (qty > 0),
    unit_price_cents bigint NOT NULL CHECK (unit_price_cents > 0),
    UNIQUE (order_id, line_no)
);
CREATE INDEX IF NOT EXISTS order_line_product_id_idx ON public.order_line (product_id);

-- The OLD system: a denormalized e-shop database with years of dirty data.
-- Runs in the legacy_shop database. Recreated by: ./run.sh source
--
-- Everything the migration has to deal with is planted here on purpose (and deterministically,
-- so the numbers in verify are reproducible):
--   customers   duplicate e-mails (different case), invalid e-mails, two date formats + an
--               impossible date, free-text countries (+ one nobody can map), phones in several
--               formats, unparseable addresses, one-word names
--   products    prices with decimal comma or point, an unparseable price, category spelled 7 ways
--   order_lines header repeated on every line, legacy status codes (+ an unknown one), qty 0,
--               qty as a word, orders of unknown customers, an order with inconsistent header
DROP SCHEMA IF EXISTS legacy CASCADE;
CREATE SCHEMA legacy;

CREATE TABLE legacy.customers (
    cust_no    int PRIMARY KEY,
    full_name  text,
    email      text,
    phone      text,
    address    text,          -- 'Main Street 5, 11005 Belgrade'
    country    text,          -- free text
    created    text,          -- 'DD.MM.YYYY' or 'YYYY-MM-DD'
    active     char(1),       -- 'A' / 'I'
    updated_at timestamp NOT NULL
);

INSERT INTO legacy.customers
SELECT n,
       CASE WHEN n % 97 = 0 THEN 'Mononym' || n
            WHEN n % 13 = 0 THEN '  First' || n || '   Last' || n || ' '
            ELSE 'First' || n || ' Last' || n END,
       CASE WHEN n % 250 = 0 THEN 'user' || n || '.example.com'                   -- no @
            WHEN n > 1900    THEN upper('user' || (n - 1900) || '@Example.com')   -- duplicate of customer n-1900
            ELSE 'user' || n || '@example.com' END,
       CASE n % 4 WHEN 0 THEN '(555) ' || lpad((n % 1000)::text, 3, '0') || '-' || lpad(n::text, 4, '0')
                  WHEN 1 THEN '+381 64 ' || lpad(n::text, 7, '0')
                  WHEN 2 THEN '064/' || lpad(n::text, 7, '0')                     -- local format, no country code
                  ELSE NULL END,
       CASE WHEN n % 50 = 0 THEN 'unknown'
            ELSE 'Main Street ' || n || ', ' || (11000 + n % 90) || ' '
                 || (ARRAY['Belgrade', 'Novi Sad', 'Berlin', 'Paris'])[1 + n % 4] END,
       CASE WHEN n % 333 = 0 THEN 'Atlantis'
            ELSE (ARRAY['Serbia', 'srbija', 'RS', 'Germany', 'DE', 'Deutschland', 'France'])[1 + n % 7] END,
       CASE WHEN n % 400 = 7 THEN '31.02.2021'                                    -- impossible date
            WHEN n % 2 = 0  THEN to_char(date '2019-01-01' + n, 'DD.MM.YYYY')
            ELSE to_char(date '2019-01-01' + n, 'YYYY-MM-DD') END,
       CASE WHEN n % 10 = 0 THEN 'I' ELSE 'A' END,
       timestamp '2026-01-01' + n * interval '1 minute'
FROM generate_series(1, 2000) AS n;

CREATE TABLE legacy.products (
    sku      text PRIMARY KEY,
    title    text,
    price    text,            -- '12,50' or '12.50'
    category text             -- free text
);

INSERT INTO legacy.products
SELECT 'SKU-' || lpad(p::text, 4, '0'),
       'Product ' || p,
       CASE WHEN p % 150 = 0 THEN 'n/a'
            WHEN p % 2 = 0   THEN replace(to_char(1 + p % 97 + (p % 100) / 100.0, 'FM9990.00'), '.', ',')
            ELSE to_char(1 + p % 97 + (p % 100) / 100.0, 'FM9990.00') END,
       (ARRAY['Books', ' books', 'BOOKS', 'Electronics', 'electronics ', 'Home & Garden', 'home & garden'])[1 + p % 7]
FROM generate_series(1, 300) AS p;

-- One row per order LINE; the order header is repeated on every line.
CREATE TABLE legacy.order_lines (
    order_no    text,
    line_no     int,
    cust_no     int,
    order_date  text,
    status_code text,         -- N, P, S, X and the old synonym PEND
    sku         text,
    qty         text,
    unit_price  text,
    updated_at  timestamp NOT NULL,
    PRIMARY KEY (order_no, line_no)
);

INSERT INTO legacy.order_lines
SELECT 'ORD-' || lpad(o::text, 6, '0'),
       l,
       CASE WHEN o % 1500 = 0 THEN 99999 ELSE 1 + (o * 7) % 2000 END,              -- 99999: unknown customer
       CASE WHEN o % 2222 = 0 AND l = 2 THEN '2023-01-01'                          -- header differs between lines
            ELSE to_char(date '2024-01-01' + o % 600, 'YYYY-MM-DD') END,
       CASE WHEN o % 1000 = 13 THEN 'Q'                                            -- unknown status code
            ELSE (ARRAY['N', 'P', 'S', 'X', 'PEND'])[1 + o % 5] END,
       p.sku,
       CASE WHEN o % 500 = 0 AND l = 1 THEN '0'
            WHEN o % 777 = 0 AND l = 1 THEN 'two'
            ELSE (1 + (o + l) % 5)::text END,
       p.price,
       timestamp '2026-01-01' + o * interval '1 minute'
FROM generate_series(1, 6000) AS o
CROSS JOIN LATERAL generate_series(1, 1 + o % 4) AS l
JOIN legacy.products p ON p.sku = 'SKU-' || lpad((1 + (o * 3 + l) % 300)::text, 4, '0');

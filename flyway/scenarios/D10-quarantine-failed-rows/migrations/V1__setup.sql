-- A legacy import table: everything is text, filled by humans and CSV exports over the years.
-- Goal: move it into a typed table. Rows that can't be converted must not abort the migration
-- and must not be lost.
CREATE TABLE legacy_payment (
    id       integer PRIMARY KEY,
    paid_on  text,
    amount   text,
    currency text
);

INSERT INTO legacy_payment (id, paid_on, amount, currency) VALUES
    (1,  '2024-02-10',  '12.50',          'EUR'),   -- clean
    (2,  '31/12/2023',  '99.99',          'eur'),   -- European date, lowercase currency
    (3,  '2024-02-30',  '10.00',          'EUR'),   -- impossible date
    (4,  'yesterday',   '5.00',           'EUR'),   -- PostgreSQL ACCEPTS this as a date!
    (5,  '2024-03-01',  '12,50',          'EUR'),   -- decimal comma
    (6,  '2024-03-02',  '1.234,56',       'EUR'),   -- thousands separator + decimal comma
    (7,  '2024-03-03',  'abc',            'EUR'),   -- not a number
    (8,  '2024-03-04',  '',               'EUR'),   -- empty
    (9,  '2024-03-05',  '99999999999.99', 'EUR'),   -- too big for numeric(12,2)
    (10, '2024-03-06',  '-5.00',          'EUR'),   -- negative: business rule
    (11, '03/07/2024',  '7.00',           'USD'),   -- European date again
    (12, '2024-13-01',  '8.00',           'EUR'),   -- month 13
    (13, NULL,          '9.00',           'EUR'),   -- missing date
    (14, '2024-03-08',  '10.00',          'EURO');  -- invalid currency code

INSERT INTO legacy_payment (id, paid_on, amount, currency)
SELECT 100 + g, to_char(date '2023-01-01' + g % 700, 'YYYY-MM-DD'), ((1 + g % 90000) / 100.0)::text, 'EUR'
FROM generate_series(1, 10000) AS g;

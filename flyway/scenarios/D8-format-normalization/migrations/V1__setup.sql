-- The same kind of value in many formats. Goal: one canonical format per column + CHECKs
-- that keep it that way.
CREATE TABLE customer (
    id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email     varchar(255) NOT NULL,
    full_name varchar(200) NOT NULL,
    phone     varchar(50)
);

INSERT INTO customer (email, full_name, phone) VALUES
    ('  John.Doe@Example.COM ', '  John    Doe ',  '(555) 123-4567'),
    ('ana@example.com',         'Ana Petrović',    '+381 64 123 4567'),
    ('MARK@EXAMPLE.COM',        'Mark  Smith',     '00 44 20 7946 0958'),
    ('lee@example.com',         'Lee Chen',        '1-555-987-6543'),
    ('kim@example.com',         'Kim Park',        'n/a'),
    ('zoe@example.com',         'Zoe Adams',       '12345'),
    ('max@example.com',         'Max Weber',       NULL);

INSERT INTO customer (email, full_name, phone)
SELECT CASE g % 3 WHEN 0 THEN 'User' || g || '@Example.com' WHEN 1 THEN ' user' || g || '@example.com' ELSE 'user' || g || '@example.com' END,
       CASE g % 2 WHEN 0 THEN 'First' || g || '  Last' ELSE 'First' || g || ' Last' END,
       CASE g % 4 WHEN 0 THEN '(555) ' || lpad((g % 1000)::text, 3, '0') || '-' || lpad((g % 10000)::text, 4, '0')
                  WHEN 1 THEN '+49 30 ' || lpad(g::text, 7, '0')
                  WHEN 2 THEN '555.' || lpad((g % 1000)::text, 3, '0') || '.' || lpad((g % 10000)::text, 4, '0')
                  ELSE NULL END
FROM generate_series(1, 20000) AS g;

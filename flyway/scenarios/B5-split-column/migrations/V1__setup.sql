CREATE TABLE customer (
    id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name varchar(200) NOT NULL
);

INSERT INTO customer (full_name) VALUES
    ('Ada Lovelace'),
    ('Mary Ann Evans'),      -- multi-word first name
    ('Cher'),                -- single word
    ('  Alan   Turing  ');   -- messy whitespace

INSERT INTO customer (full_name)
SELECT 'First' || g || ' Last' || g FROM generate_series(1, 10000) AS g;

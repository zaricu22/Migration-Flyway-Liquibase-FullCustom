-- Shared starting point (main branch). Two developers branch off from here.
CREATE TABLE customer (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name  text NOT NULL,
    email text NOT NULL
);

INSERT INTO customer (name, email)
SELECT 'Customer ' || g, 'user' || g || '@example.com' FROM generate_series(1, 1000) AS g;

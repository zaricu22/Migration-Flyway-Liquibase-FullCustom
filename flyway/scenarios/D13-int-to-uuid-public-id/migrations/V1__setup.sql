-- The API exposes sequential ids: /customers/1, /customers/2, ... (guessable, leaks volume).
-- Goal: a random public UUID next to the internal bigint id. No table rewrite, no long lock.
CREATE TABLE customer (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email varchar(255) NOT NULL
);

INSERT INTO customer (email)
SELECT 'user' || g || '@example.com' FROM generate_series(1, 300000) AS g;

CREATE TABLE _demo_filenode (step text PRIMARY KEY, filenode oid NOT NULL);
INSERT INTO _demo_filenode VALUES ('1 after V1', pg_relation_filenode('customer'));

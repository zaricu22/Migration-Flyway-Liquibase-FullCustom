CREATE TABLE customer (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email varchar(255) NOT NULL
);

INSERT INTO customer (email)
SELECT 'user' || g || '@example.com' FROM generate_series(1, 200000) AS g;

-- Demo helper: remember the physical file of the table. If a later ALTER rewrites the table,
-- PostgreSQL writes a new file and the filenode changes.
CREATE TABLE _demo_filenode (step text PRIMARY KEY, filenode oid NOT NULL);
INSERT INTO _demo_filenode VALUES ('after V1', pg_relation_filenode('customer'));

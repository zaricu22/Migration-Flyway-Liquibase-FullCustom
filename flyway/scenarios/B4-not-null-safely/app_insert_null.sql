-- An app that still writes explicit NULLs. Accepted after V1, rejected from V2 on
-- (NOT VALID constraints are enforced for new rows immediately).
\set ON_ERROR_STOP off
INSERT INTO customer (email, country_code) VALUES ('legacy-app@example.com', NULL);
\echo '--- An insert that omits the column gets the default (from V2 on):'
INSERT INTO customer (email) VALUES ('new-app@example.com') RETURNING id, email, country_code;

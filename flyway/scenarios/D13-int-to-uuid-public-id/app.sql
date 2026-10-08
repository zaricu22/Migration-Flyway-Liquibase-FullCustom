-- The API now looks customers up by public_id; the internal id stays for joins and FKs.
\echo '--- New customer: public_id comes from the column default'
INSERT INTO customer (email) VALUES ('api-' || floor(random() * 1e6) || '@example.com')
RETURNING id, public_id, email;

\echo '--- GET /customers/{public_id} uses the unique index'
EXPLAIN (COSTS OFF)
SELECT id, email FROM customer WHERE public_id = '00000000-0000-4000-8000-000000000000';

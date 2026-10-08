-- OLD application writes legacy codes. Translated by the trigger from V2 on; rejected by the CHECK after V4.
\echo '--- app v1 writes P and X (+ refunded_at)'
INSERT INTO orders (status) VALUES ('P');
INSERT INTO orders (status, refunded_at) VALUES ('X', now());
SELECT id, status, refunded_at FROM orders ORDER BY id DESC LIMIT 2;

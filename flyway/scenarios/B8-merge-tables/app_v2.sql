-- NEW application: profile columns live on customer. Works from V4 on.
\echo '--- app v2'
UPDATE customer SET bio = 'Written by app v2' WHERE id = 2;
SELECT id, email, bio, avatar_url FROM customer WHERE id IN (1, 2, 3) ORDER BY id;

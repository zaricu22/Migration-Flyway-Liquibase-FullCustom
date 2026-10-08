-- MIGRATE: copy existing profiles into customer. (Batch on large tables, see D2.)
UPDATE customer c
SET bio = p.bio, avatar_url = p.avatar_url
FROM customer_profile p
WHERE p.customer_id = c.id
  AND (c.bio, c.avatar_url) IS DISTINCT FROM (p.bio, p.avatar_url);

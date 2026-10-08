-- Deduplicate customers in ONE transaction: if any step fails, nothing is merged.

-- 1. Decide the survivor per group: the OLDEST account (then lowest id) wins.
--    The mapping table is kept as an audit trail ("where did customer 5123 go?").
CREATE TABLE customer_merge_map (
    duplicate_id bigint PRIMARY KEY,
    survivor_id  bigint NOT NULL,
    merged_at    timestamptz NOT NULL DEFAULT now()
);

-- Only the duplicates are inserted, not the survivors themselves.
INSERT INTO customer_merge_map (duplicate_id, survivor_id)
SELECT id, survivor_id
FROM (
    SELECT id,
           first_value(id) OVER (PARTITION BY lower(trim(email)) ORDER BY created_at, id) AS survivor_id
    FROM customer
) ranked
WHERE id <> survivor_id;

-- 2. Merge attributes: the survivor keeps its own values but takes missing ones from duplicates
--    (here: the newest non-null phone).
UPDATE customer s
SET phone = d.phone
FROM (
    SELECT DISTINCT ON (m.survivor_id) m.survivor_id, c.phone
    FROM customer_merge_map m
    JOIN customer c ON c.id = m.duplicate_id
    WHERE c.phone IS NOT NULL
    ORDER BY m.survivor_id, c.created_at DESC
) d
WHERE s.id = d.survivor_id AND s.phone IS NULL;

-- 3. Repoint child rows to the survivor.
--    Simple case: no uniqueness involved.
UPDATE orders o
SET customer_id = m.survivor_id
FROM customer_merge_map m
WHERE o.customer_id = m.duplicate_id;

--    TRAP: wishlist has PRIMARY KEY (customer_id, product_id). If the survivor and a duplicate
--    both have product 1, a plain UPDATE raises a unique violation.
--    Copy to the survivor with ON CONFLICT DO NOTHING, then delete the duplicate's rows.
INSERT INTO wishlist (customer_id, product_id)
SELECT m.survivor_id, w.product_id
FROM wishlist w
JOIN customer_merge_map m ON m.duplicate_id = w.customer_id
ON CONFLICT (customer_id, product_id) DO NOTHING;

DELETE FROM wishlist w
USING customer_merge_map m
WHERE w.customer_id = m.duplicate_id;

-- 4. Delete the duplicates. The FKs have no ON DELETE CASCADE on purpose: if we forgot to
--    repoint some child table, this DELETE fails and the whole migration rolls back
--    instead of silently deleting that table's rows.
--    (Columns WITHOUT a FK that store customer ids, e.g. in a log table, are NOT protected.
--    Search for them explicitly.)
DELETE FROM customer c
USING customer_merge_map m
WHERE c.id = m.duplicate_id;

-- 5. Normalize the survivors' emails and lock the rule in with a unique index, in the same
--    transaction, so no new duplicate can slip in between cleanup and constraint.
--    (For a big table: build it CONCURRENTLY in a separate migration and be ready to re-run
--    the dedup if the build fails.)
UPDATE customer SET email = lower(trim(email)) WHERE email <> lower(trim(email));
CREATE UNIQUE INDEX customer_email_lower_uq ON customer (lower(email));

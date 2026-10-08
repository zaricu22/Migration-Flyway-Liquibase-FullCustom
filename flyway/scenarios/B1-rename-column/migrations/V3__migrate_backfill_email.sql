-- MIGRATE: copy existing values. Small table -> one statement.
-- On a large table, backfill in batches (D2) and make the column NOT NULL safely (B4).
UPDATE customer SET email = mail WHERE email IS NULL;

ALTER TABLE customer ALTER COLUMN email SET NOT NULL;

-- >>> Deploy app v2 (uses only "email") and retire all app v1 instances before V4. <<<

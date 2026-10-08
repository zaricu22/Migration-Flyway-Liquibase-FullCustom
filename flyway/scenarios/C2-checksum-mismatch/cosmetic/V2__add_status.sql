-- The ORIGINAL V2, as it was applied to every database.
-- Edited later: only this comment was added (e.g. a ticket reference, ORD-123). The SQL is unchanged,
-- but the checksum covers the whole file, comments included.
ALTER TABLE orders ADD COLUMN status text NOT NULL DEFAULT 'new';

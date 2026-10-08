-- Adding an enum value is a cheap catalog change (no table rewrite).
-- AFTER/BEFORE controls the sort order (enum values compare by position, not alphabetically).
-- IF NOT EXISTS makes it re-runnable.
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'cancelled' AFTER 'paid';

-- Using the new value in THIS transaction fails with
--   "unsafe use of new value "cancelled" of enum type order_status".
-- That's why the data change lives in V3 (a separate transaction).

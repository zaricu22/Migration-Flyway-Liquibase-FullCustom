-- Adding an enum value and using it in the same transaction fails.
\set ON_ERROR_STOP off

BEGIN;
ALTER TYPE order_status ADD VALUE 'refunded';
UPDATE orders SET status = 'refunded' WHERE id = 1;   -- ERROR: unsafe use of new value
ROLLBACK;

\echo '--- Enum values cannot be removed: there is no ALTER TYPE ... DROP VALUE.'
\echo '--- Removing a value means: new type, convert the column (table rewrite), drop old type.'

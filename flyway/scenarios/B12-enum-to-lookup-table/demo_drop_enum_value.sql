-- Run after V1..V3 (while the enum still exists): PostgreSQL has no way to remove an enum value.
\echo '--- ALTER TYPE ... DROP VALUE does not exist'
DO $$
BEGIN
    EXECUTE 'ALTER TYPE order_status DROP VALUE ''on_hold''';
    RAISE NOTICE 'unexpected: value dropped';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'expected error: %', SQLERRM;
END $$;

\echo '--- After V3 the retired value is rejected, also when app v1 writes it through the enum'
DO $$
BEGIN
    INSERT INTO orders (amount, status) VALUES (1.00, 'on_hold');
    RAISE NOTICE 'unexpected: on_hold accepted';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'expected error: %', SQLERRM;
END $$;

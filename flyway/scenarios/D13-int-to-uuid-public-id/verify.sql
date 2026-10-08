\echo '--- Table file (same filenode = never rewritten)'
SELECT * FROM _demo_filenode ORDER BY step;

\echo '--- Sample'
SELECT id, public_id, email FROM customer ORDER BY id LIMIT 3;

DO $$
BEGIN
    IF (SELECT count(DISTINCT filenode) FROM _demo_filenode) <> 1 THEN
        RAISE EXCEPTION 'FAIL: table was rewritten';
    END IF;
    IF NOT (SELECT attnotnull FROM pg_attribute WHERE attrelid = 'customer'::regclass AND attname = 'public_id') THEN
        RAISE EXCEPTION 'FAIL: public_id is nullable';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'customer'::regclass AND conname = 'customer_public_id_uq') THEN
        RAISE EXCEPTION 'FAIL: unique constraint missing';
    END IF;
    IF (SELECT count(DISTINCT public_id) FROM customer) <> (SELECT count(*) FROM customer) THEN
        RAISE EXCEPTION 'FAIL: duplicate public ids';
    END IF;
    RAISE NOTICE 'OK: every customer has a unique public_id, table never rewritten';
END $$;

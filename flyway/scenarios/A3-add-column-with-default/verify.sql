\echo '--- Table file per step (a new filenode = the table was rewritten)'
SELECT * FROM _demo_filenode ORDER BY step;

\echo '--- Catalog right after V2: status is served from attmissingval, rows were not touched'
SELECT * FROM _demo_missing;

DO $$
DECLARE
    v1 oid; v2 oid; v3 oid;
BEGIN
    SELECT filenode INTO v1 FROM _demo_filenode WHERE step LIKE '1%';
    SELECT filenode INTO v2 FROM _demo_filenode WHERE step LIKE '2%';
    SELECT filenode INTO v3 FROM _demo_filenode WHERE step LIKE '3%';

    IF v1 <> v2 THEN RAISE EXCEPTION 'FAIL: constant default rewrote the table'; END IF;
    RAISE NOTICE 'OK: constant default -> no rewrite';

    IF v2 = v3 THEN RAISE EXCEPTION 'FAIL: volatile default did not rewrite the table'; END IF;
    RAISE NOTICE 'OK: volatile default -> full table rewrite';
END $$;

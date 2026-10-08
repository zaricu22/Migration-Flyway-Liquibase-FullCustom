-- Expected: 454 bytes, md5 66a8e52c1a0d918a46f57f677fea31ef (same as `md5sum logo.png`)
SELECT file_name, length(content) AS bytes, md5(content) AS md5 FROM attachment;
\echo 'The naive "blob" column is an oid: a pointer to pg_largeobject, not the bytes themselves.'
\echo 'Deleting the row does NOT delete the large object (orphans unless you use lo_unlink / the lo extension).'
SELECT format_type(atttypid, atttypmod) AS content_naive_type FROM pg_attribute
WHERE attrelid = 'attachment'::regclass AND attname = 'content_naive';

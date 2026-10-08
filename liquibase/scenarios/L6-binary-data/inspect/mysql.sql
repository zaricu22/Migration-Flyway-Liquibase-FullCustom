-- Expected: 454 bytes, md5 66a8e52c1a0d918a46f57f677fea31ef
SELECT file_name, length(content) AS bytes, md5(content) AS md5 FROM attachment;

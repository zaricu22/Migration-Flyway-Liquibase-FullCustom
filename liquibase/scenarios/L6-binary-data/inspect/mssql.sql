SET NOCOUNT ON;
-- Expected: 454 bytes, md5 66a8e52c1a0d918a46f57f677fea31ef
SELECT file_name, DATALENGTH(content) AS bytes,
       LOWER(CONVERT(varchar(32), HASHBYTES('MD5', content), 2)) AS md5
FROM attachment;

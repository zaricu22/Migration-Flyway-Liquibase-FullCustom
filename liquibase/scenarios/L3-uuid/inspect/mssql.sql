SET NOCOUNT ON;
-- uniqueidentifier sorts by the LAST group first: a different ORDER BY result than the other engines.
SELECT id, name FROM api_key ORDER BY id;
SELECT TOP 1 DATALENGTH(id) AS bytes_per_value FROM api_key;
-- Invalid value -> rejected by the type:
INSERT INTO api_key (id, name) VALUES ('not-a-uuid', 'garbage');

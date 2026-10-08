SET NOCOUNT ON;
SELECT * FROM event_user ORDER BY id;
-- nvarchar(max) keeps the text exactly as written:
SELECT payload FROM event WHERE id = 1;
-- Invalid JSON -> rejected ONLY because of the ISJSON check constraint:
INSERT INTO event (id, payload) VALUES (99, '{broken');

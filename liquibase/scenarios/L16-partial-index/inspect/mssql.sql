SET NOCOUNT ON;
-- TRAP: a table with a FILTERED index only accepts writes from sessions with
-- QUOTED_IDENTIFIER ON (and ANSI_NULLS ON, ...). JDBC/ODBC drivers set it; sqlcmd does NOT (unless -I):
INSERT INTO account VALUES (1, 'ana@example.com', DATEADD(year, -1, GETDATE()));
GO
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO
INSERT INTO account VALUES (1, 'ana@example.com', DATEADD(year, -1, GETDATE()));  -- deleted
INSERT INTO account VALUES (2, 'ana@example.com', DATEADD(day, -1, GETDATE()));   -- deleted again: OK
INSERT INTO account VALUES (3, 'ana@example.com', NULL);                          -- active: OK
GO
-- Second ACTIVE account with the same email -> rejected:
INSERT INTO account VALUES (4, 'ana@example.com', NULL);
GO
SELECT * FROM account ORDER BY id;

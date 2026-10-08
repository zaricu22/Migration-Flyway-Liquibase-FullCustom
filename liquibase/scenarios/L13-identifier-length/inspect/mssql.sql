SET NOCOUNT ON;
-- Liquibase history: changeset 3 EXECUTED (index found and dropped)
SELECT id, exectype FROM DATABASECHANGELOG ORDER BY orderexecuted;
-- Indexes left (the long one was dropped by changeset 3):
SELECT name, LEN(name) AS len FROM sys.indexes WHERE object_id = OBJECT_ID('shipment_event') ORDER BY name;

-- Liquibase history: changeset 3 EXECUTED (index found and dropped)
SELECT id, exectype FROM DATABASECHANGELOG ORDER BY orderexecuted;
-- Indexes left (the long one was dropped by changeset 3):
SELECT DISTINCT index_name, length(index_name) AS len FROM information_schema.statistics
WHERE table_schema = DATABASE() AND table_name = 'shipment_event' ORDER BY 1;
-- 66 characters -> error, no silent truncation:
CREATE INDEX ix_shipment_tracking_event_carrier_code_status_created_on_region_x ON shipment_event (region);

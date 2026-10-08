\echo 'Liquibase history: changeset 3 was MARK_RAN (precondition "index exists" failed), not EXECUTED'
SELECT id, exectype FROM databasechangelog ORDER BY orderexecuted;
\echo 'Indexes left (the 63-char index SURVIVED changeset 3 because the precondition did not find it):'
SELECT indexname, length(indexname) AS len FROM pg_indexes WHERE tablename = 'shipment_event' ORDER BY 1;
\echo 'Two different 64-char names that share the first 63 chars -> the SAME name after truncation:'
CREATE INDEX ix_shipment_tracking_event_carrier_code_status_created_on_regio2 ON shipment_event (region);

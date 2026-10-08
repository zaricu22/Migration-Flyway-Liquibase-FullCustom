SET NOCOUNT ON;
-- Default constraints on customer: generated (system) name vs given name
SELECT dc.name AS constraint_name, c.name AS column_name, dc.is_system_named, dc.definition
FROM sys.default_constraints dc
JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id
WHERE dc.parent_object_id = OBJECT_ID('customer')
ORDER BY c.column_id;
-- Recorded changesets:
SELECT id, exectype FROM DATABASECHANGELOG ORDER BY orderexecuted;

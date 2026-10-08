SET NOCOUNT ON;
INSERT INTO audit_event (id, note) VALUES (1, 'inserted');
SELECT created_at, created_at_precise, created_on, updated_at FROM audit_event;
WAITFOR DELAY '00:00:01.200';
UPDATE audit_event SET note = 'updated' WHERE id = 1;
-- after UPDATE (trigger moved updated_at):
SELECT note, created_at_precise, updated_at FROM audit_event;

INSERT INTO audit_event (id, note) VALUES (1, 'inserted');
SELECT created_at, created_at_precise, created_on, updated_at FROM audit_event;
DO SLEEP(1.2);
UPDATE audit_event SET note = 'updated' WHERE id = 1;
-- after UPDATE (ON UPDATE CURRENT_TIMESTAMP moved updated_at):
SELECT note, created_at_precise, updated_at FROM audit_event;

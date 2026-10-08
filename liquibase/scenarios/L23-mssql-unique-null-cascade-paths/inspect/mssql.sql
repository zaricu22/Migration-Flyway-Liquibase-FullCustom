SET NOCOUNT ON;
-- Customers (two NULL tax numbers are allowed by the FILTERED unique index):
SELECT * FROM customer ORDER BY id;
-- A duplicate NON-NULL tax number is rejected (expected error):
INSERT INTO customer (id, tax_number) VALUES (4, 'RS100');
-- Deleting a project that still has assignments is rejected, NO ACTION (expected error):
DELETE FROM project WHERE id = 2;
-- Deleting an employee removes its assignments (CASCADE):
DELETE FROM employee WHERE id = 1;
SELECT * FROM assignment ORDER BY employee_id, project_id;
-- Deleting a project: its assignments first, then the project:
DELETE FROM assignment WHERE project_id = 2;
DELETE FROM project WHERE id = 2;
SELECT id FROM project ORDER BY id;
-- How the unique rule is implemented here:
SELECT name, is_unique, has_filter, filter_definition FROM sys.indexes
WHERE object_id = OBJECT_ID('customer') AND name = 'uq_customer_tax_number';

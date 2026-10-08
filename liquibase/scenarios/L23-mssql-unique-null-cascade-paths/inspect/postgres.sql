\echo 'Customers (two NULL tax numbers are allowed):'
SELECT * FROM customer ORDER BY id;
\echo 'A duplicate NON-NULL tax number is rejected (expected error):'
INSERT INTO customer (id, tax_number) VALUES (4, 'RS100');
\echo 'Deleting a project that still has assignments is rejected, NO ACTION (expected error):'
DELETE FROM project WHERE id = 2;
\echo 'Deleting an employee removes its assignments (CASCADE):'
DELETE FROM employee WHERE id = 1;
SELECT * FROM assignment ORDER BY employee_id, project_id;
\echo 'Deleting a project: its assignments first, then the project:'
DELETE FROM assignment WHERE project_id = 2;
DELETE FROM project WHERE id = 2;
SELECT id FROM project ORDER BY id;

-- OLD application: uses table "item". Works after V1 and V2 (through the view). Fails after V3.
\echo '--- app v1: insert / update / select on item'
INSERT INTO item (name, price) VALUES ('Inserted by app v1', 9.99);
UPDATE item SET price = price + 1 WHERE id = 1;
SELECT id, name, price FROM item WHERE id = 1 OR id = (SELECT max(id) FROM item) ORDER BY id;

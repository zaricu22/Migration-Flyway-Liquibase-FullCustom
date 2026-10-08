-- Same columns in the same order (LIKE), so "INSERT ... SELECT *" / "RETURNING *" line up.
-- LIKE copies NOT NULL but not identity, indexes or FKs: archive ids are copied, not generated.
CREATE TABLE orders_archive     (LIKE orders     INCLUDING DEFAULTS INCLUDING CONSTRAINTS);
CREATE TABLE order_item_archive (LIKE order_item INCLUDING DEFAULTS INCLUDING CONSTRAINTS);

ALTER TABLE orders_archive     ADD PRIMARY KEY (id);
ALTER TABLE order_item_archive ADD PRIMARY KEY (id);
ALTER TABLE order_item_archive ADD FOREIGN KEY (order_id) REFERENCES orders_archive (id);
CREATE INDEX order_item_archive_order_id_idx ON order_item_archive (order_id);

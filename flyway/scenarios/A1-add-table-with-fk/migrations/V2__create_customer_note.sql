-- A brand-new table referencing an existing one.
-- Safe: customer_note is empty, so validating the FK is instant. Adding the FK still takes a
-- SHARE ROW EXCLUSIVE lock on customer (blocks writes to customer briefly, reads keep working).
CREATE TABLE customer_note (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id bigint      NOT NULL REFERENCES customer (id) ON DELETE CASCADE,
    body        text        NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- PostgreSQL does NOT index FK columns automatically. Without this index every DELETE on
-- customer (ON DELETE CASCADE) and every join customer -> customer_note scans customer_note.
CREATE INDEX customer_note_customer_id_idx ON customer_note (customer_id);

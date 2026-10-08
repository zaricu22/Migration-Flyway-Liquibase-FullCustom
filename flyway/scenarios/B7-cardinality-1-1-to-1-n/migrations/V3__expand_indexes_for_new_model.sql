-- Prepare all indexes the 1:N model needs while the 1:1 PK still protects the data.
-- (On a big live table: CREATE INDEX CONCURRENTLY in a non-transactional migration, see A4.)

-- Future primary key.
CREATE UNIQUE INDEX address_id_uq ON address (id);

-- "Exactly one primary address per customer": a PARTIAL unique index.
-- Uniqueness applies only to rows WHERE is_primary, so any number of non-primary addresses is allowed.
CREATE UNIQUE INDEX address_one_primary_per_customer_uq ON address (customer_id) WHERE is_primary;

-- The FK column loses its PK index in V4 -> it needs a normal index for joins and cascades.
CREATE INDEX address_customer_id_idx ON address (customer_id);

-- >>> Deploy app v2 before V4: it reads WHERE is_primary and no longer relies on
-- >>> ON CONFLICT (customer_id), because that uniqueness disappears in V4.

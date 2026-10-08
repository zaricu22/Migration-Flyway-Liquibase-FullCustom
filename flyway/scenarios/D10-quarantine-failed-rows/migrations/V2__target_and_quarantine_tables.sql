CREATE TABLE payment (
    id       integer       PRIMARY KEY,               -- same id as the legacy row: traceable
    paid_on  date          NOT NULL,
    amount   numeric(12,2) NOT NULL CHECK (amount > 0),
    currency char(3)       NOT NULL CHECK (currency ~ '^[A-Z]{3}$')
);

-- Quarantine: one row per problem (a source row can have several).
CREATE TABLE payment_migration_error (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_id   integer     NOT NULL,
    column_name text        NOT NULL,
    raw_value   text,
    error       text        NOT NULL,
    logged_at   timestamptz NOT NULL DEFAULT now()
);

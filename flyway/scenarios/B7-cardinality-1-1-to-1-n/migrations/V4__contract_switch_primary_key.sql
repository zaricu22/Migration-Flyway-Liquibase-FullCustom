-- CONTRACT: swap the primary key. From now on a customer can have many addresses.
-- Both steps are metadata-only (the index for the new PK already exists) -> short lock.
SET LOCAL lock_timeout = '5s';

ALTER TABLE address DROP CONSTRAINT address_pkey;
ALTER TABLE address ADD CONSTRAINT address_pkey PRIMARY KEY USING INDEX address_id_uq;

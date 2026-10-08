-- Columns -> JSON: rarely used, mostly-NULL contact fields become one jsonb document.
-- jsonb_strip_nulls() drops the NULL keys; an empty object becomes NULL.
ALTER TABLE customer ADD COLUMN contact_extra jsonb;

UPDATE customer
SET contact_extra = nullif(jsonb_strip_nulls(jsonb_build_object('fax', fax, 'twitter', twitter, 'skype', skype)), '{}')
WHERE fax IS NOT NULL OR twitter IS NOT NULL OR skype IS NOT NULL;

-- Containment queries (contact_extra @> '{"twitter": "@alice"}') can use this index.
CREATE INDEX customer_contact_extra_idx ON customer USING gin (contact_extra jsonb_path_ops);

ALTER TABLE customer DROP COLUMN fax, DROP COLUMN twitter, DROP COLUMN skype;

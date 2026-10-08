-- JSON -> columns. JSON has no schema, so each key comes in several shapes:
--   "newsletter": true | "yes" | 1 | missing ...     "language": "en" | "DE" | legacy key "lang"
-- jsonb_typeof() lets the conversion handle each shape explicitly instead of a blind cast
-- ('yes'::boolean works, but '1'::boolean from a JSON number doesn't, and an object would fail).
ALTER TABLE customer ADD COLUMN newsletter boolean NOT NULL DEFAULT false;
ALTER TABLE customer ADD COLUMN language   varchar(5);

UPDATE customer
SET newsletter = CASE jsonb_typeof(preferences -> 'newsletter')
                     WHEN 'boolean' THEN (preferences ->> 'newsletter')::boolean
                     WHEN 'string'  THEN lower(preferences ->> 'newsletter') IN ('yes', 'y', 'true', '1')
                     WHEN 'number'  THEN (preferences ->> 'newsletter')::numeric <> 0
                     ELSE false                                    -- missing / null / unexpected
                 END,
    language   = lower(coalesce(preferences ->> 'language', preferences ->> 'lang'))
WHERE preferences IS NOT NULL;

-- Now it's a real column: indexable, typed, constrained.
ALTER TABLE customer ADD CONSTRAINT customer_language_format CHECK (language ~ '^[a-z]{2}$');
CREATE INDEX customer_newsletter_idx ON customer (newsletter) WHERE newsletter;

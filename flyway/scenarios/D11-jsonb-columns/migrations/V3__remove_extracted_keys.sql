-- Contract: remove the extracted keys from the JSON, so there's ONE source of truth.
-- (Run this only after the app reads the columns. Keys nobody extracted, like "theme", stay.)
UPDATE customer
SET preferences = preferences - 'newsletter' - 'language' - 'lang'
WHERE preferences ?| ARRAY['newsletter', 'language', 'lang'];

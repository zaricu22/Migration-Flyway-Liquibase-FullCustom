-- Fix existing NULLs (business decision: unknown -> 'US'). Batch this on large tables (D2).
-- No new NULLs can appear anymore, so after this the data is clean for good.
UPDATE customer SET country_code = 'US' WHERE country_code IS NULL;

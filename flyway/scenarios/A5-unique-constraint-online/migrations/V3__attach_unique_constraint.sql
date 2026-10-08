-- Step 2: turn the ready index into a real constraint. Metadata only, instant.
-- Why bother when the unique index already enforces uniqueness?
--   * constraints are visible in information_schema (ORMs, schema diff tools)
--   * "ON CONFLICT ON CONSTRAINT customer_email_uq" needs a constraint
--   * the same technique works for PRIMARY KEY ... USING INDEX (see B7, B9)
ALTER TABLE customer ADD CONSTRAINT customer_email_uq UNIQUE USING INDEX customer_email_uq;

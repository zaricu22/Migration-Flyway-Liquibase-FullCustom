-- GATE 3: production matches staging and the known business facts.
-- PASS -> go-live decision.  FAIL -> investigate; if it can't be fixed forward: 07_cutover/790_rollback.sql
\o /dev/null
SELECT mig.gate('verify');

-- GATE 2: staging must match the source exactly (minus the documented rejects). Otherwise stop:
-- nothing has touched production yet, so fixing a rule and rerunning costs nothing.
\o /dev/null
SELECT mig.gate('reconcile');

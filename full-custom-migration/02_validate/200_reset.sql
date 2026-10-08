-- Validation is repeatable: re-running it replaces this run's findings instead of adding to them.
DELETE FROM mig.error WHERE run_id = mig.current_run() AND phase = 'validate';

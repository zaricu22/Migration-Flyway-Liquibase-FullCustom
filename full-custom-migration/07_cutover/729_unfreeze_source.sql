-- NO-GO path: the cutover was called off, the old system stays the live system and must accept
-- writes again. Undoes 720_freeze_source.sql (affects new sessions).
ALTER DATABASE legacy_shop RESET default_transaction_read_only;

\echo 'Old system unfrozen: legacy_shop accepts writes again (new sessions).'

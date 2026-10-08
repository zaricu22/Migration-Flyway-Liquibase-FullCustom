SELECT id, name, enabled FROM feature_flag ORDER BY id;
SELECT count(*) AS enabled_flags FROM feature_flag WHERE enabled;           -- boolean is a real predicate

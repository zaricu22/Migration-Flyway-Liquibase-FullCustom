SET NOCOUNT ON;
SELECT id, name, enabled FROM feature_flag ORDER BY id;
SELECT count(*) AS enabled_flags FROM feature_flag WHERE enabled = 1;       -- "WHERE enabled" alone is a syntax error

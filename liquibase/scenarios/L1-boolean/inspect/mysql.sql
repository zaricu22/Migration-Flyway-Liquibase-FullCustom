-- Liquibase maps boolean to TINYINT on MySQL (MySQL's own BOOLEAN is TINYINT(1) as well).
-- Nothing stops a value like 7 from being stored: a "boolean" is just a small integer here.
SELECT id, name, enabled FROM feature_flag ORDER BY id;
SELECT count(*) AS enabled_flags FROM feature_flag WHERE enabled = TRUE;    -- TRUE is 1 in MySQL

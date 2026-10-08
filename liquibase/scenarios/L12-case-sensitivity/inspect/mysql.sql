SELECT @@lower_case_table_names AS lower_case_table_names;
-- Names as stored:
SELECT table_name, column_name FROM information_schema.columns
WHERE table_schema = DATABASE() AND table_name NOT LIKE 'DATABASECHANGELOG%' ORDER BY 1, 2;
-- Exact case: works
SELECT * FROM CustomerOrder;
-- Column names are case-INsensitive:
SELECT orderdate FROM CustomerOrder;
-- Table names are case-SENSITIVE on Linux (would work on Windows/macOS!):
SELECT * FROM customerorder;

-- Load 400,000 rows twice: into a table WITH indexes, and into one WITHOUT indexes followed by
-- building the same indexes once. Run after V1 (needs product_import). Compare the timings.
\timing on

\echo '--- A: load into a table with 3 secondary indexes'
CREATE TEMP TABLE load_indexed (sku varchar(30), name varchar(200), category_id int, price numeric(12,2));
CREATE UNIQUE INDEX ON load_indexed (sku);
CREATE INDEX ON load_indexed (name);
CREATE INDEX ON load_indexed (category_id);
INSERT INTO load_indexed SELECT * FROM product_import;

\echo '--- B: load without indexes...'
CREATE TEMP TABLE load_plain (sku varchar(30), name varchar(200), category_id int, price numeric(12,2));
INSERT INTO load_plain SELECT * FROM product_import;
\echo '--- ...then build the same indexes once'
SET maintenance_work_mem = '256MB';
CREATE UNIQUE INDEX ON load_plain (sku);
CREATE INDEX ON load_plain (name);
CREATE INDEX ON load_plain (category_id);

\timing off
\echo '(FK checks and row triggers add even more per-row cost on top of the indexes.)'

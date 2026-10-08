-- Run in a second terminal while V3 is running: progress is visible because every batch commits.
-- (With a single big UPDATE this would show 0 until the very end.)
SELECT count(*) FILTER (WHERE order_number IS NOT NULL) AS done,
       count(*)                                         AS total,
       round(100.0 * count(*) FILTER (WHERE order_number IS NOT NULL) / count(*), 1) AS pct
FROM orders;

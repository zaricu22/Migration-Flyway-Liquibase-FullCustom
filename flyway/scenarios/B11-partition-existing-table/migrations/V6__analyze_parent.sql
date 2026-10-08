-- Autovacuum analyzes the partitions, but NEVER the partitioned parent itself.
-- Without parent statistics, queries over several partitions get poor estimates.
-- Re-run ANALYZE on the parent after big loads (or schedule it).
ANALYZE event;

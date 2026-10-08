-- The wrong conversions next to the right ones (literals only, can run at any time).

\echo '--- Money: floor/trunc vs round'
SELECT price,
       floor(price * 100)::bigint AS floor_cents_WRONG,
       round(price * 100)::bigint AS round_cents_RIGHT
FROM (VALUES (0.29::float8), (0.57), (1.15), (4.35), (19.99)) AS t(price);

\echo '--- Time: interpreting Belgrade local time as UTC (what ALTER TYPE without USING does in a UTC session)'
SET TIME ZONE 'UTC';
SELECT local_ts AS stored_value,
       local_ts::timestamptz                       AS no_using_WRONG,
       local_ts AT TIME ZONE 'Europe/Belgrade'     AS using_at_time_zone_RIGHT
FROM (VALUES (timestamp '2025-07-01 12:00'), (timestamp '2025-01-15 12:00')) AS t(local_ts);

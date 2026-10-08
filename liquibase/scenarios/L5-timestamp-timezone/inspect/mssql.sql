SET NOCOUNT ON;
-- datetimeoffset keeps the ORIGINAL offset; datetime2 silently dropped it (12:00, but 12:00 where?).
SELECT starts_at, starts_at_naive, SWITCHOFFSET(starts_at, '+00:00') AS starts_at_utc FROM meeting;

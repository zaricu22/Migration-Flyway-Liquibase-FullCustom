# L5 — Timestamp with time zone

**Conflict:** "a point in time" is stored three different ways, and the abstract Liquibase type `timestamp with time zone` fails on MySQL and silently loses the offset on SQL Server.

| | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| Abstract `timestamp with time zone` | `timestamptz` | ❌ **syntax error** | `datetime2`, **offset silently dropped** |
| Recommended (property `tstz_type`) | `timestamptz` | `datetime(6)` + "always UTC" convention | `datetimeoffset(6)` |
| What is stored | the instant (UTC internally) | a wall-clock value, zone unknown | wall-clock value **+ its offset** |
| Abstract `timestamp` (naive) | `timestamp` (no zone) | `TIMESTAMP`: converted to UTC, **ends 2038-01-19** | `datetime2` (no zone) |

**Same insert on every engine:** `'2025-07-01 12:00:00+02:00'`
```
                        starts_at                              starts_at_naive
postgres  (UTC view)    2025-07-01 10:00:00+00                 2025-07-01 12:00:00   <- offset ignored!
postgres  (NY view)     2025-07-01 06:00:00-04  (same instant) 2025-07-01 12:00:00
mysql     (UTC)         2025-07-01 10:00:00.000000             2025-07-01 10:00:00
mysql     (-04:00)      2025-07-01 10:00:00.000000  <- fixed   2025-07-01 06:00:00   <- TIMESTAMP follows the session
mssql                   2025-07-01 12:00:00 +02:00  (kept!)    2025-07-01 12:00:00   <- offset dropped
mysql: INSERT '2040-01-01' into TIMESTAMP -> ERROR 1292 Incorrect datetime value
```

**Traps**
- **PostgreSQL `timestamp` ignores offsets** in input. `12:00+02:00` is stored as `12:00`, and the zone is gone.
- **MySQL has no zone-aware type.** `TIMESTAMP` converts to and from the *session* time zone and ends in **2038**. `DATETIME` stores what you give it. MySQL 8.0.19+ converts literals with an offset to the session zone on insert, which is why the `datetime(6)` column holds 10:00 UTC. The convention "store UTC, connect with `time_zone = '+00:00'`" is up to you.
- **SQL Server `datetimeoffset` keeps the original offset** (useful for "what local time did the user see?"). Converting to UTC needs `SWITCHOFFSET(..., '+00:00')`.
- The same wall-clock value means different instants per engine unless every writer uses the same convention.

**Liquibase solution:** a per-engine **property** for the type. Never use the abstract `timestamp with time zone`.

**Run**
```bash
./run.sh L5
```

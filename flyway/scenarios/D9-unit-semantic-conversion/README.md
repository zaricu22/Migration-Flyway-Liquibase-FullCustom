# D9 — Unit / semantic conversion

**Goal:** conversions where the type change is easy but the **meaning** is the trap. Nothing fails, and the data is just wrong.

| Version | What it does |
|---|---|
| V1 | `created_at timestamp` holding **Belgrade local time**, `price double precision` in euros |
| V2 | `ALTER ... TYPE timestamptz USING created_at AT TIME ZONE 'Europe/Belgrade'` |
| V3 | `price_cents = round(price * 100)`, **assert** before dropping `price` |

**Trap 1: time zones**
- `timestamp` (without time zone) doesn't record what zone the value was in. You have to know, for example from the app server's time zone.
- `ALTER COLUMN ... TYPE timestamptz` **without `USING`** interprets values in the *session* time zone. In a UTC session, Belgrade `12:00` becomes `12:00 UTC`: shifted by 2 hours in summer and 1 in winter, with no error.
- `USING ... AT TIME ZONE 'Europe/Belgrade'` handles DST per row. Check the DST-switch nights: an **ambiguous** local time (02:30 happened twice) and a **nonexistent** one (02:30 skipped). PostgreSQL resolves both without an error:
  - the ambiguous `02:30` is read as **standard time**, the second occurrence (`01:30 UTC`);
  - the nonexistent `02:30` is shifted forward and becomes **`03:30` local** (`01:30 UTC`).

  Decide whether that's acceptable, or fix those rows explicitly.

**Trap 2: float money**
- `0.29` as a float is `0.28999999999999998`, so `floor(0.29 * 100)` = **28**. Use `round()`.
- **Assert before you drop the source.** V3 checks that every value is within half a cent and that the totals match. Only then does it drop `price`. If the check fails, the transaction rolls back and nothing is lost.

`V2` rewrites the table under lock. On large tables, use the expand/contract approach from **B3**, with the same `USING` expression in the backfill.

**Run**
```bash
./run.sh D9 sql demo_wrong_conversions.sql   # wrong vs right, side by side
./run.sh D9 all
```

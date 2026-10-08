# D7 — Value remapping

**Goal:** replace legacy status codes (`N`, `PEND`, `P`, `S`, `X`) with readable ones (`new`, `paid`, `shipped`, `cancelled`, `refunded`) while the old app still writes the old codes.

| Version | What it does |
|---|---|
| V1 | 100,000 orders with legacy codes. `PEND` is a historical synonym of `N`. `X` means cancelled *or* refunded |
| V2 | `status_mapping` table, a **pre-flight assertion** (fail on unmapped codes), new-codes-only `CHECK ... NOT VALID`, and a translation trigger for app v1 |
| V3 | Convert existing rows (mapping join + conditional rule), `VALIDATE` |
| V4 | Drop the translation trigger. The mapping table stays as documentation |

**Mapping shapes covered**
| Shape | Example | How |
|---|---|---|
| 1:1 | `P → paid` | Mapping table |
| Many-to-one | `N`, `PEND → new` | Mapping table |
| One-to-many (conditional) | `X → cancelled` or `refunded` (if `refunded_at` is set) | `CASE` on top of the join |

**Key points**
- **The mapping is data, not code.** A table is reviewable, joinable and stays around to explain old reports.
- **Pre-flight assertion:** a `DO` block raises an exception if any value has no mapping, and the whole migration rolls back. Stopping is better than silently mapping unknown values to NULL or a default.
- The `BEFORE` trigger translates app v1's writes **before** the new `CHECK` sees them, so the constraint can already require new codes.
- The same conditional rule appears in the trigger and in the conversion. Keep them identical.

**Run step by step**
```bash
./run.sh D7 clean
./run.sh D7 migrate 2 && ./run.sh D7 sql app_v1.sql        # P -> paid, X + refunded_at -> refunded
./run.sh D7 sql demo_preflight.sql                          # unmapped 'ZZ', 'Q' -> migration would stop
./run.sh D7 migrate   && ./run.sh D7 sql app_v1.sql        # after V4: CHECK violation (app v1 retired)
```
For a clean verify: `./run.sh D7 all`

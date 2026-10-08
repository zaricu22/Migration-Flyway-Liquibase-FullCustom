# D1 — Reference / seed data

**Goal:** manage lookup data (countries, statuses) with migrations. Compare **versioned** and **repeatable** seeds.

| File | Type | What it does |
|---|---|---|
| `V1__schema.sql` | Versioned | `country`, `order_status`, `orders` (FKs to both) |
| `V2__seed_countries.sql` | Versioned | `INSERT ... ON CONFLICT DO NOTHING`: runs once, part of history |
| `R__order_status.sql` | Repeatable | Desired-state upsert. Re-runs whenever the file changes |

**Versioned vs repeatable**

| | Versioned `V2__` | Repeatable `R__` |
|---|---|---|
| Runs | Once | Every time its checksum changes (after all `V` migrations) |
| Changing data | New migration `V3__...` | Edit the file |
| Editing after it ran | ❌ `validate` fails with a checksum mismatch | ✅ That's the point |
| Must be idempotent | Recommended | **Required** |
| Good for | Data tied to a point in history | Lists you maintain: statuses, permissions, feature flags |

**Key points**
- The repeatable seed is **desired-state**. It inserts new codes, updates changed ones, and **deactivates** removed ones. Deleting would break the FK from `orders`, and history needs the old codes.
- The `IS DISTINCT FROM` guard in `ON CONFLICT DO UPDATE` avoids rewriting unchanged rows: no dead tuples, no triggers fired.
- **Repeatable migrations run after all versioned ones.** On a fresh database, a `V3__` that inserts orders with status `paid` would fail, because `R__order_status` hasn't run yet. Versioned migrations must not depend on repeatable data.
- Seeds that are only for dev/test (fake customers, demo orders) don't belong in these migrations. Keep them in a separate Flyway `locations` entry that only dev environments include.

**Run**
```bash
./run.sh D1 all
# Edit migrations/R__order_status.sql (e.g. add ('refunded', 'Refunded', 40) and remove 'cancelled'), then:
./run.sh D1 migrate    # Flyway: Migrating schema "d1" with repeatable migration "order status"
./run.sh D1 verify     # 'cancelled' is now active = false
```

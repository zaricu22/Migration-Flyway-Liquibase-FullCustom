# B3 — Change a column type

**Goal:** know which type changes are free, and do the expensive ones (`float8 → numeric`) without a table rewrite under lock.

| Version | Phase | What it does |
|---|---|---|
| V1 | — | `orders(note varchar(50), amount double precision)`, 200,000 rows |
| V2 | In place | `note varchar(50) → varchar(200)`: catalog-only, **no rewrite** |
| V3 | Expand | Add `total_amount numeric(12,2)` + bidirectional sync trigger (with `round`) |
| V4 | Migrate | Backfill `total_amount = round(amount::numeric, 2)`, `SET NOT NULL` |
| — | Deploy | App v2 uses `total_amount` |
| V5 | Contract | Drop trigger + `amount` |

**Type changes without a rewrite** (only a brief lock):
- `varchar(n) → varchar(m)` with `m > n`
- `varchar(n) → text`
- `numeric(p,s) → numeric(p2,s)` with `p2 > p`

**Type changes that rewrite the table** under `ACCESS EXCLUSIVE`:
- `int → bigint`
- `float → numeric`
- `text → int`
- `timestamp → timestamptz` (unless the session time zone is UTC)
- anything that changes the storage format or needs `USING`

For these, use expand/contract, or accept the lock on small tables.

**Key points**
- The `_demo_filenode` table proves no step rewrote `orders`.
- Two columns can't share a name, so the new column gets a new name. Keeping the old name costs one more rename phase and one more app deploy.
- Convert floats with `round(x::numeric, 2)`. A plain cast would keep float noise like `0.30000000000000004`.

**Run step by step**
```bash
./run.sh B3 clean
./run.sh B3 migrate 3 && ./run.sh B3 sql app_v1.sql                               # trigger fills total_amount
./run.sh B3 migrate 4 && ./run.sh B3 sql app_v1.sql && ./run.sh B3 sql app_v2.sql  # both in sync
./run.sh B3 migrate   && ./run.sh B3 verify
```

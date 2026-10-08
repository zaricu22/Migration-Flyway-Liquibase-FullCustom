# B12 — Remove an enum value: enum → lookup table (expand/contract)

**Goal:** retire the status `on_hold` from a PostgreSQL enum while old and new app versions run side by side, and make future status changes data instead of DDL.

> **Not yet run against the containers.** The behavior below is expected from PostgreSQL 17; run the commands to confirm it.

PostgreSQL can add (**A7**) and rename enum values, but it **can't remove one**: there is no `ALTER TYPE ... DROP VALUE`.

| Version | Phase | What it does |
|---|---|---|
| V1 | — | Enum `order_status` with 5 values, `orders.status` (10,000 rows, 200 `on_hold`) |
| V2 | Expand | Lookup table `order_status_code`, column `status_code` with an FK `NOT VALID`, bidirectional sync trigger |
| V3 | Migrate | Backfill `status_code`, move `on_hold` orders to `new`, `DELETE` the `on_hold` row, validate the FK, `SET NOT NULL` |
| — | Deploy | Roll out app v2 (uses `status_code` + lookup table), retire app v1 |
| V4 | Contract | Drop trigger, function, `status` column and the enum type; `status_code` gets the default |

**The two ways to remove an enum value**

| | Recreate the enum without the value | Convert to a lookup table (this scenario) |
|---|---|---|
| How | New type, `ALTER COLUMN status TYPE new_type USING status::text::new_type`, drop old type, rename | Expand/contract, as above |
| Lock | **Full table rewrite under `ACCESS EXCLUSIVE`** | Short locks only |
| Old app during the change | Breaks if it writes the removed value; fine otherwise | Keeps working until the contract step |
| Next change | The same exercise again | `INSERT` / `DELETE` in the lookup table |

A `varchar` + `CHECK (status IN (...))` is a third option: changing the list means replacing the constraint (`NOT VALID` + `VALIDATE`, **A6**), which is cheap but still DDL.

**Key points**
- **The lookup table can't have the enum's name.** Every table also creates a row type with the same name, so `CREATE TABLE order_status` fails while the enum exists.
- **Removing a value becomes a `DELETE`, guarded by the FK.** It fails while any order still uses the value, so the data decision (`on_hold` → `new`) has to come first.
- **From V3 on, the retired value is rejected everywhere.** Even app v1, writing the enum, fails: the trigger copies `on_hold` into `status_code`, and the FK refuses it (`demo_drop_enum_value.sql`).
- **New statuses must wait for the contract step.** While the trigger casts codes back to the enum, a code that doesn't exist in the enum (e.g. `refunded`) fails. After V4 it's just a new row (`demo_new_status.sql`).
- **No `DEFAULT` on the new column while the trigger runs.** The trigger takes a non-NULL `status_code` as "written by app v2"; a default would overwrite what app v1 inserted. The default moves over in V4.
- **Lookup rows are reference data:** in a real project they belong in a migration or an `R__` script (**D1**).

**Run step by step**
```bash
./run.sh B12 clean
./run.sh B12 migrate 1 && ./run.sh B12 sql app_v1.sql                                 # only v1 works
./run.sh B12 migrate 3 && ./run.sh B12 sql app_v1.sql && ./run.sh B12 sql app_v2.sql   # both work, in sync
./run.sh B12 sql demo_drop_enum_value.sql                                             # no DROP VALUE; on_hold rejected
./run.sh B12 migrate   && ./run.sh B12 sql app_v2.sql                                 # contract: only v2
./run.sh B12 sql app_v1.sql        # fails: column "status" does not exist (expected)
./run.sh B12 sql demo_new_status.sql
./run.sh B12 verify
```

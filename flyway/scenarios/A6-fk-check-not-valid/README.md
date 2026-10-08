# A6 — Add a FK / CHECK as `NOT VALID`, then `VALIDATE`

**Goal:** add constraints to a large existing table without blocking traffic during the scan of existing rows.

| Version | What it does | Lock |
|---|---|---|
| V1 | `customer` (10,000 rows) + `orders` (300,000 rows) with no constraints | — |
| V2 | `ADD CONSTRAINT ... NOT VALID` (FK + CHECK) | Brief. No scan of existing rows |
| V3 | `VALIDATE CONSTRAINT` | `SHARE UPDATE EXCLUSIVE`: reads and writes continue during the scan |

**Key points**
- A plain `ADD CONSTRAINT` checks every existing row while holding a lock that blocks writes.
- A `NOT VALID` constraint is still **enforced for new rows** right away. Only the check of existing rows is postponed.
- V2 and V3 must be **separate migrations** (separate transactions). Otherwise V2's stronger lock is held during the whole validation.
- If existing rows violate the constraint, V3 fails. Clean the data up between V2 and V3 (**D3** shows that order).

**Run**
```bash
./run.sh A6 all
```

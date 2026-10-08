# D8 — Format normalization

**Goal:** bring emails, names and phone numbers into one canonical format, and keep them there.

| Version | What it does |
|---|---|
| V1 | `'  John.Doe@Example.COM '`, `'  John    Doe '`, `(555) 123-4567`, `00 44 20 7946 0958`, `n/a`... |
| V2 | `normalize_email/name/phone()` functions, a pre-flight collision check, `phone_raw` backup, and an `UPDATE` of **only the rows that change** |
| V3 | `CHECK` constraints that call the same functions + `UNIQUE (email)` |

| Column | Canonical form | Rule |
|---|---|---|
| email | `john.doe@example.com` | `lower(btrim())` |
| full_name | `John Doe` | trim + collapse whitespace |
| phone | `+15551234567` (E.164) | `+…` keep · `00…` → `+` · 10 digits → `+1…` · otherwise NULL |

**Key points**
- **Normalization can create duplicates.** `Ana@x.com` and `ana@x.com` become the same value. The pre-flight check stops the migration if that would happen, so deduplicate first (**D4**).
- **Rules live in `IMMUTABLE` functions**, used by the migration and by the `CHECK` constraints. The same rules could also be used in the app or in expression indexes.
- **Lossy rules keep the original.** `phone_raw` stores the input, so unparseable numbers (`n/a`, `12345`) can be reviewed and the rules revisited. The default country (`+1`) is a business assumption.
- **Only update rows that change** (`WHERE x IS DISTINCT FROM f(x)`). Each `UPDATE` writes a new row version, so rewriting clean rows only produces bloat and WAL.
- **Lock the format in.** Without the `CHECK`s, the next app release reintroduces mixed formats.

**Run**
```bash
./run.sh D8 all
```

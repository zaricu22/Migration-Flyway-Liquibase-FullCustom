# L15 — Upsert (insert or update)

**Conflict:** every engine has its own upsert syntax, and some have none worth using.

| | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| Native syntax | `INSERT ... ON CONFLICT (key) DO UPDATE SET x = EXCLUDED.x` | `INSERT ... AS new ON DUPLICATE KEY UPDATE x = new.x` | `MERGE ... WHEN MATCHED ... WHEN NOT MATCHED ...;` |
| Conflict target | explicit (column list / constraint) | **any** unique key of the table | explicit `ON` condition |
| Concurrency-safe | yes | yes | only with `WITH (HOLDLOCK)` |

**Liquibase's portable option: `loadUpdateData`** (upsert from a CSV, keyed by `primaryKey`). It generates a different strategy per engine:
```sql
-- postgresql: DO block, update first, insert if nothing was found
DO $$ BEGIN
  UPDATE product_price SET price = '25.00', ... WHERE sku = 'B';
  IF not found THEN INSERT INTO product_price (...) VALUES ('B', '25.00', ...); END IF;
END; $$ LANGUAGE plpgsql;
-- mysql: native
INSERT INTO product_price (...) VALUES ('B', '25.00', ...) ON DUPLICATE KEY UPDATE price = '25.00', ...;
-- mssql: count, then IF/ELSE
DECLARE @reccount integer
SELECT @reccount = count(*) FROM product_price WHERE sku = 'B'
IF @reccount = 0 BEGIN INSERT ... END ELSE BEGIN UPDATE ... END;
```

**Result** (same on every engine):
```
A  15.00  native            <- loadData, then native upsert (update path)
B  25.00  loadUpdateData    <- loadData, then loadUpdateData (update path)
C  30.00  loadUpdateData    <- loadUpdateData (insert path)
D  40.00  native            <- native upsert (insert path)
```

**Notes**
- The PostgreSQL and SQL Server `loadUpdateData` variants are **check-then-act**. That's fine for a migration (one writer), but not a pattern to copy into application code.
- MySQL's `ON DUPLICATE KEY` fires on **any** unique key, not only the one you meant. A second unique column can turn an intended insert into an update of a different row.
- MySQL 8.0.19+ uses a row alias (`AS new ... new.price`). The older `VALUES(price)` function is deprecated.
- `MERGE` has to end with `;`, and without `HOLDLOCK` two concurrent `MERGE`s can both insert.

**Run**
```bash
./run.sh L15
./run.sh L15 mssql yaml sql     # see what loadUpdateData generates
```

# L6 — Binary data

**Conflict:** binary column types, size limits and binary literals all differ, and the abstract `blob` type means something special on PostgreSQL.

| | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| Abstract `blob` | **`oid`**: a large-object *reference* | `BLOB` (**max 64 KB**) | `varbinary(max)` |
| Recommended (property `binary_type`) | `bytea` (up to 1 GB) | `longblob` (up to 4 GB) | `varbinary(max)` (up to 2 GB) |
| Hex literal | `'\x89504e47'` / `decode(...)` | `X'89504E47'` | `0x89504E47` |
| Length / hash | `length()`, `md5()` | `length()`, `md5()` | `DATALENGTH()`, `HASHBYTES('MD5', ...)` |

**Result:** `logo.png` (454 bytes) inserted with `valueBlobFile` has the same MD5 on every engine (`66a8e52c1a0d918a46f57f677fea31ef`).

**Traps**
- **PostgreSQL `oid` is not "bytes in the row".** It points to an entry in `pg_largeobject`. Deleting or updating the row does **not** delete the large object: you get orphans unless you call `lo_unlink()` or use the `lo` extension's trigger. Unless you need streaming access to huge files, use `bytea`.
- **MySQL `BLOB` holds only 64 KB.** Larger inserts fail in strict mode. Use `mediumblob` (16 MB) or `longblob`.
- **Binary literals are dialect-specific.** Raw SQL with hex values needs a variant per engine.

**Liquibase solution**
- A **property** for the column type.
- **`valueBlobFile`** (or `loadData` with a `BLOB` column type): Liquibase reads the file and binds it as a JDBC binary parameter, so no literal syntax is needed in the changelog.

**Run**
```bash
./run.sh L6
```

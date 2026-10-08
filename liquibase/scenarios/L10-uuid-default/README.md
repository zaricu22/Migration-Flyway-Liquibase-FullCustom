# L10 — UUID default

**Conflict:** generating a UUID in the database uses a different function on each engine, with different syntax rules and even a different **kind** of UUID.

| | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| Default (property `uuid_default`) | `gen_random_uuid()` | `(UUID())`, parentheses required | `NEWID()` |
| UUID version | **v4** (random) | **v1** (time + node id) | **v4** (random) |
| Index-friendly variant | `uuidv7()` (PostgreSQL 18+) | `UUID_TO_BIN(UUID(), 1)` into `binary(16)` | `NEWSEQUENTIALID()`, **default only** |
| Output format | lowercase | lowercase (text) | **UPPERCASE** |

Generated values:
```
postgres  d726083f-ce1f-4c88-8748-1e3063f5c0d8   v4 random
mysql     82f9649c-b838-11f1-9c66-928fe863b8e7   v1: ...-11f1-... = version 1, same last group on every row
          82f9a115-b838-11f1-9c66-928fe863b8e7
mssql     661C3F74-3915-4303-AEE4-CCBD0C3918B6   v4 random
mssql     0DFA423E-F36B-1410-8D18-00162C24E1B0   NEWSEQUENTIALID: first group increases
          14FA423E-F36B-1410-8D18-00162C24E1B0
```

**Traps**
- **MySQL expression defaults need parentheses:** `DEFAULT (UUID())`. Without them the statement is a syntax error.
- **MySQL `UUID()` is version 1.** It's time-based, and the last group comes from the server's node id (MAC address), so it can reveal *when* and *where* a value was created. Generate v4 in the application if that matters.
- **`NEWSEQUENTIALID()`** only works as a column default, not in `SELECT` or `INSERT`. It is sequential **in SQL Server's sort order** (see **L3**), and restarts from a different base after a server restart.
- **SQL Server returns uppercase UUIDs.** Text comparisons in the application (`"abc..." == "ABC..."`) can fail, so compare them as UUID types.

**Liquibase solution:** a **property** for the default expression. The column type `uuid` itself is portable (see **L3**).

**Run**
```bash
./run.sh L10
```

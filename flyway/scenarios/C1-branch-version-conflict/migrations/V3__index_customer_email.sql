-- Developer B (branch feature/email-index), merged SECOND.
-- Originally written as V2 (see branch-b/), RENUMBERED to the next free version when merging,
-- because version 2 was already taken on main. Only possible while V2 of branch B has not been
-- applied anywhere yet (no shared database has it in its history).
CREATE UNIQUE INDEX customer_email_uq ON customer (lower(email));

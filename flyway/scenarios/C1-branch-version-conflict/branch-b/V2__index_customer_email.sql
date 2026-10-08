-- Developer B's ORIGINAL file on branch feature/email-index: also version 2, because V1 was the
-- latest version when the branch was created. Combined with main (migrations/), Flyway finds two
-- migrations with version 2 and refuses to run anything.
CREATE UNIQUE INDEX customer_email_uq ON customer (lower(email));

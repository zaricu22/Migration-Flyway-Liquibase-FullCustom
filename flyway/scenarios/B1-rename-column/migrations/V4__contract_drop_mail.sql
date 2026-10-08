-- CONTRACT: nobody uses "mail" anymore. Remove the sync machinery and the old column.
SET LOCAL lock_timeout = '5s';

DROP TRIGGER customer_sync_mail_email ON customer;
DROP FUNCTION customer_sync_mail_email();
ALTER TABLE customer DROP COLUMN mail;

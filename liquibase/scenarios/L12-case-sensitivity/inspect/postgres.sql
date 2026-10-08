\echo 'Names as stored in the catalog:'
SELECT table_name, column_name FROM information_schema.columns
WHERE table_schema = 'public' AND table_name NOT LIKE 'databasechangelog%' ORDER BY 1, 2;
\echo '"CustomerOrder" (LEGACY -> quoted, mixed case): unquoted queries FAIL'
SELECT * FROM CustomerOrder;
SELECT * FROM "CustomerOrder";
\echo 'customerinvoice (QUOTE_ONLY_RESERVED_WORDS -> folded): any unquoted spelling works'
SELECT * FROM CustomerInvoice;
SELECT invoicedate FROM CUSTOMERINVOICE;

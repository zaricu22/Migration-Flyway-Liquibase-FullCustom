-- Customers: exclude rejected, normalize, DEDUPLICATE, map country.
--
-- Duplicate rule (a business decision): same e-mail after normalization = same person.
-- The OLDEST account survives (then the lowest number). Duplicates are not lost: they become
-- aliases of the survivor, and their orders are moved to the survivor.

-- 1. alias map: every accepted legacy number -> its survivor
INSERT INTO stg.customer_alias (legacy_cust_no, survivor_cust_no)
SELECT cust_no::int,
       first_value(cust_no::int) OVER (PARTITION BY mig.normalize_email(email)
                                       ORDER BY mig.parse_date(created), cust_no::int)
FROM raw.v_customers c
WHERE NOT EXISTS (SELECT 1 FROM mig.v_rejected r WHERE r.entity = 'customer' AND r.source_key = c.cust_no);

-- 2. one row per survivor. Missing values are taken from its duplicates (here: the phone).
INSERT INTO stg.customer (legacy_cust_no, email, first_name, last_name, phone, country_code, created_on, active)
SELECT s.cust_no::int,
       mig.normalize_email(s.email),
       mig.name_first(s.full_name),
       mig.name_last(s.full_name),
       coalesce(mig.normalize_phone(s.phone),
                (SELECT mig.normalize_phone(d.phone)
                 FROM stg.customer_alias a
                 JOIN raw.v_customers d ON d.cust_no::int = a.legacy_cust_no
                 WHERE a.survivor_cust_no = s.cust_no::int AND mig.normalize_phone(d.phone) IS NOT NULL
                 ORDER BY a.legacy_cust_no LIMIT 1)),
       (SELECT m.new_code FROM mig.code_map m WHERE m.entity = 'country' AND m.old_code = lower(btrim(s.country))),
       mig.parse_date(s.created),
       s.active = 'A'
FROM raw.v_customers s
JOIN stg.customer_alias a ON a.legacy_cust_no = s.cust_no::int AND a.survivor_cust_no = a.legacy_cust_no;

SELECT count(*) FILTER (WHERE legacy_cust_no = survivor_cust_no)  AS survivors,
       count(*) FILTER (WHERE legacy_cust_no <> survivor_cust_no) AS merged_duplicates
FROM stg.customer_alias;

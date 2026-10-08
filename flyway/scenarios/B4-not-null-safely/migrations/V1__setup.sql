CREATE TABLE customer (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email        varchar(255) NOT NULL,
    country_code char(2)                  -- nullable, ~10% NULLs. Goal: make it NOT NULL.
);

INSERT INTO customer (email, country_code)
SELECT 'user' || g || '@example.com',
       CASE WHEN g % 10 = 0 THEN NULL ELSE (ARRAY['US', 'DE', 'RS', 'FR'])[1 + g % 4] END
FROM generate_series(1, 300000) AS g;

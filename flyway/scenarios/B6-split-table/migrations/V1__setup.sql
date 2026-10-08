-- Address fields live inside customer. Goal: move them into their own table (1:1).
CREATE TABLE customer (
    id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email  varchar(255) NOT NULL,
    street varchar(200),
    city   varchar(100),
    zip    varchar(20)
);

INSERT INTO customer (email, street, city, zip)
SELECT 'user' || g || '@example.com',
       CASE WHEN g % 5 = 0 THEN NULL ELSE g || ' Main Street' END,
       CASE WHEN g % 5 = 0 THEN NULL ELSE (ARRAY['Belgrade', 'Berlin', 'Paris'])[1 + g % 3] END,
       CASE WHEN g % 5 = 0 THEN NULL ELSE lpad((g % 99999)::text, 5, '0') END
FROM generate_series(1, 20000) AS g;

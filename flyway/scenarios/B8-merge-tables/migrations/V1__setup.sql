-- Profile data was split into a 1:1 side table. Goal: merge it back into customer.
CREATE TABLE customer (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email varchar(255) NOT NULL
);

CREATE TABLE customer_profile (
    customer_id bigint PRIMARY KEY REFERENCES customer (id) ON DELETE CASCADE,
    bio         text,
    avatar_url  varchar(500)
);

INSERT INTO customer (email)
SELECT 'user' || g || '@example.com' FROM generate_series(1, 10000) AS g;

INSERT INTO customer_profile (customer_id, bio, avatar_url)
SELECT id, 'Bio of customer ' || id, 'https://cdn.example.com/avatars/' || id || '.png'
FROM customer WHERE id % 3 = 0;

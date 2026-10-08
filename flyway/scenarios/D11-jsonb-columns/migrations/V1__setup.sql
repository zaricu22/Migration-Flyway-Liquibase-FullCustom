-- Two opposite problems in one table:
--   * preferences (jsonb): some keys are queried/filtered constantly -> they deserve real columns
--   * fax / twitter / skype: sparse legacy columns, almost always NULL -> better packed into jsonb
CREATE TABLE customer (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       varchar(255) NOT NULL,
    preferences jsonb,
    fax         varchar(50),
    twitter     varchar(50),
    skype       varchar(50)
);

INSERT INTO customer (email, preferences, fax, twitter, skype) VALUES
    ('a@example.com', '{"newsletter": true,  "language": "en", "theme": "dark"}', NULL, '@alice', NULL),
    ('b@example.com', '{"newsletter": "yes", "language": "DE"}',                  '+49 30 1234', NULL, NULL),
    ('c@example.com', '{"newsletter": 1}',                                        NULL, NULL, 'carl.s'),
    ('d@example.com', '{"lang": "fr"}',                                           NULL, NULL, NULL),  -- legacy key name
    ('e@example.com', '{}',                                                       NULL, NULL, NULL),
    ('f@example.com', NULL,                                                       NULL, NULL, NULL),
    ('g@example.com', '{"newsletter": "no", "language": "sr", "theme": "light"}', NULL, NULL, NULL);

INSERT INTO customer (email, preferences, twitter)
SELECT 'user' || g || '@example.com',
       jsonb_build_object('newsletter', g % 2 = 0, 'language', (ARRAY['en', 'de', 'sr'])[1 + g % 3]),
       CASE WHEN g % 50 = 0 THEN '@user' || g END
FROM generate_series(1, 20000) AS g;

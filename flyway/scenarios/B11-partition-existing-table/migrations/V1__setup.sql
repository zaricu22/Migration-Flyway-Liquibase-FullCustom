-- Old model: one big, ever-growing table. Goal: make it RANGE-partitioned by month
-- without copying the 200,000 existing rows and without a long lock.
CREATE SEQUENCE event_id_seq;

CREATE TABLE event (
    id         bigint NOT NULL DEFAULT nextval('event_id_seq') PRIMARY KEY,
    created_at timestamptz NOT NULL,
    kind       text NOT NULL,
    payload    text
);
ALTER SEQUENCE event_id_seq OWNED BY event.id;

-- 200,000 events from 2026-01-01 to 2026-06-30 (one every 78 seconds)
INSERT INTO event (created_at, kind, payload)
SELECT timestamptz '2026-01-01 00:00+00' + g * interval '78 seconds',
       (ARRAY['view', 'click', 'buy'])[1 + g % 3],
       'payload ' || g
FROM generate_series(0, 199999) AS g;

CREATE INDEX event_created_at_idx ON event (created_at);

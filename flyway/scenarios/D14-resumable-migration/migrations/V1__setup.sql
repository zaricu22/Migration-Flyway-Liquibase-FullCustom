-- A long-running data migration (think hours on real data). If it's killed half-way (deploy
-- timeout, failover, Ctrl+C), the re-run must continue where it stopped, not start over.
CREATE TABLE document (
    id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    body text NOT NULL
);

INSERT INTO document (body)
SELECT CASE WHEN g % 100 = 0 THEN '   '
            ELSE repeat('lorem ipsum ', g % 40) || 'dolor' END
FROM generate_series(1, 300000) AS g;

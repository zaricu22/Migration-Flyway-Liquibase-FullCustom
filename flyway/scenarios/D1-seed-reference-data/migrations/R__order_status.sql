-- REPEATABLE seed: this file describes the DESIRED STATE of the order_status list.
-- Flyway re-runs it whenever its checksum changes (i.e. whenever you edit it), after all
-- versioned migrations. So it must be idempotent: running it twice = same result.
--
-- Edit the VALUES list, run migrate again:
--   * new codes are inserted
--   * changed labels / sort orders are updated
--   * codes removed from the list are DEACTIVATED, not deleted (orders still reference them)
WITH desired (code, label, sort_order) AS (
    VALUES
        ('new',       'New',       10),
        ('paid',      'Paid',      20),
        ('shipped',   'Shipped',   30),
        ('cancelled', 'Cancelled', 90)
),
upserted AS (
    INSERT INTO order_status (code, label, sort_order, active)
    SELECT code, label, sort_order, true FROM desired
    ON CONFLICT (code) DO UPDATE
        SET label = EXCLUDED.label, sort_order = EXCLUDED.sort_order, active = true
        WHERE (order_status.label, order_status.sort_order, order_status.active)
              IS DISTINCT FROM (EXCLUDED.label, EXCLUDED.sort_order, true)
    RETURNING code
)
UPDATE order_status
SET active = false
WHERE active AND code NOT IN (SELECT code FROM desired);

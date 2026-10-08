-- VERSIONED seed: data that is written once and then belongs to the history.
-- Changing it later = a NEW versioned migration (never edit this file after it ran:
-- Flyway would fail validation with a checksum mismatch).
-- ON CONFLICT DO NOTHING keeps it safe if some rows already exist (e.g. created manually).
INSERT INTO country (code, name) VALUES
    ('RS', 'Serbia'),
    ('DE', 'Germany'),
    ('FR', 'France'),
    ('US', 'United States')
ON CONFLICT (code) DO NOTHING;

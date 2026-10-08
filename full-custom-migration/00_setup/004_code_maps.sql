-- Value mappings are REFERENCE DATA: validation needs them (is this code known?) as much as the
-- transformation (what does it become?), so they are set up before both.
-- Keys are normalized (lower + trim), so ' Srbija' and 'SRBIJA' hit the same entry.
INSERT INTO mig.code_map (entity, old_code, new_code) VALUES
    ('country', 'serbia',        'RS'),
    ('country', 'srbija',        'RS'),
    ('country', 'rs',            'RS'),
    ('country', 'germany',       'DE'),
    ('country', 'deutschland',   'DE'),
    ('country', 'de',            'DE'),
    ('country', 'france',        'FR'),
    ('country', 'fr',            'FR'),
    ('order_status', 'n',        'new'),
    ('order_status', 'pend',     'new'),      -- historical synonym
    ('order_status', 'p',        'paid'),
    ('order_status', 's',        'shipped'),
    ('order_status', 'x',        'cancelled')
ON CONFLICT (entity, old_code) DO UPDATE SET new_code = EXCLUDED.new_code;

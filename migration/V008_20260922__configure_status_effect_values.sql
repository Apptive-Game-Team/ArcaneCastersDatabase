-- Status effects can be applied by several spells and prefabs, so their shared balance
-- values live on the existing game configuration object instead of one field prefab.
-- no-tags: this migration registers neither a game object nor a magic.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM game_objects WHERE name = 'game') THEN
        RAISE EXCEPTION 'The game configuration object is required for status effect values';
    END IF;
END $$;

INSERT INTO parameters (name)
SELECT name
FROM (VALUES
    ('burn_duration'),
    ('burn_total_damage'),
    ('wet_duration'),
    ('wet_nature_heal'),
    ('shock_stun_duration'),
    ('shock_refresh_duration'),
    ('snare_duration'),
    ('snare_fire_damage'),
    ('snare_slow_percent'),
    ('leaf_field_heal_duration'),
    ('leaf_field_heal_amount'),
    ('sandstorm_effect_duration'),
    ('sandstorm_effect_damage'),
    ('building_snare_heal')
) AS required(name)
WHERE true
ON CONFLICT (name) DO NOTHING;

INSERT INTO parameter_values (game_object_id, parameter_id, value)
SELECT go.id, p.id, required.value
FROM (VALUES
    ('burn_duration', 3.0),
    ('burn_total_damage', 3.0),
    ('wet_duration', 3.0),
    ('wet_nature_heal', 3.0),
    ('shock_stun_duration', 0.5),
    ('shock_refresh_duration', 3.0),
    ('snare_duration', 3.0),
    ('snare_fire_damage', 5.0),
    ('snare_slow_percent', 0.5),
    ('leaf_field_heal_duration', 3.0),
    ('leaf_field_heal_amount', 1.0),
    ('sandstorm_effect_duration', 0.5),
    ('sandstorm_effect_damage', 1.0),
    ('building_snare_heal', 1.0)
) AS required(name, value)
JOIN parameters p ON p.name = required.name
JOIN game_objects go ON go.name = 'game'
WHERE true
ON CONFLICT (parameter_id, game_object_id) DO NOTHING;

DO $$
DECLARE
    missing text;
BEGIN
    SELECT string_agg(required.name, ', ' ORDER BY required.name)
    INTO missing
    FROM (VALUES
        ('burn_duration'), ('burn_total_damage'), ('wet_duration'),
        ('wet_nature_heal'), ('shock_stun_duration'), ('shock_refresh_duration'),
        ('snare_duration'), ('snare_fire_damage'), ('snare_slow_percent'),
        ('leaf_field_heal_duration'), ('leaf_field_heal_amount'),
        ('sandstorm_effect_duration'), ('sandstorm_effect_damage'),
        ('building_snare_heal')
    ) AS required(name)
    WHERE NOT EXISTS (
        SELECT 1
        FROM game_objects go
        JOIN parameter_values pv ON pv.game_object_id = go.id
        JOIN parameters p ON p.id = pv.parameter_id
        WHERE go.name = 'game' AND p.name = required.name AND pv.value IS NOT NULL
    );

    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'Missing status effect parameters: %', missing;
    END IF;
END $$;

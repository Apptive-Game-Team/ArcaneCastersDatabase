-- V028: registers the three PVE-only prefabs of the gate adventure (V027) and their parameters.
-- The card's DimensionToad walks to the player and spawns card-strength tadpoles every 5 s, so
-- the gate adventure gets its own variants instead of sharing the card rows:
--   pve_dimension_toad    stationary gate keeper (hp 800, spawn_interval 10)
--   pve_fire_tadpole      hp 30, damage 12, speed 0.9, attack_interval 1.0, duration 20
--   pve_lightning_tadpole hp 30, damage 10, speed 1.0, attack_interval 1.0, duration 20
-- Every key the card rows carry and this migration does not set (mass, radius, detection_range,
-- panic_duration, and for the toad also speed, damage, attack_interval, range) is copied from
-- dimension_toad, fire_tadpole and lightning_tadpole. magic_id and mana_cost are not copied: the
-- PVE variants are not cards. The numbers are first guesses to be tuned by playing.
-- Deploy order: this must apply before a game server that reads these parameters.
-- Idempotent: game_objects and parameter_values use ON CONFLICT and a second run resets the values.
-- no-tags: the PVE prefabs are enemy-only and never enter a bot deck, so counter tags do not apply.

INSERT INTO game_objects(name)
VALUES ('pve_dimension_toad'), ('pve_fire_tadpole'), ('pve_lightning_tadpole')
ON CONFLICT (name) DO NOTHING;

-- Keys copied from the card prefab, then overridden by the explicit values below.
WITH copy_sources(object_name, source_name) AS (
    VALUES
        ('pve_dimension_toad', 'dimension_toad'),
        ('pve_fire_tadpole', 'fire_tadpole'),
        ('pve_lightning_tadpole', 'lightning_tadpole')
),
copied AS (
    SELECT cs.object_name, p.id AS parameter_id, pv.value
    FROM copy_sources cs
    JOIN game_objects src ON src.name = cs.source_name
    JOIN parameter_values pv ON pv.game_object_id = src.id
    JOIN parameters p ON p.id = pv.parameter_id
    WHERE p.name NOT IN ('magic_id', 'mana_cost')
),
overrides(object_name, parameter_name, value) AS (
    VALUES
        ('pve_dimension_toad', 'hp', 800.0),
        ('pve_dimension_toad', 'spawn_interval', 10.0),
        ('pve_fire_tadpole', 'hp', 30.0),
        ('pve_fire_tadpole', 'damage', 12.0),
        ('pve_fire_tadpole', 'speed', 0.9),
        ('pve_fire_tadpole', 'attack_interval', 1.0),
        ('pve_fire_tadpole', 'duration', 20.0),
        ('pve_lightning_tadpole', 'hp', 30.0),
        ('pve_lightning_tadpole', 'damage', 10.0),
        ('pve_lightning_tadpole', 'speed', 1.0),
        ('pve_lightning_tadpole', 'attack_interval', 1.0),
        ('pve_lightning_tadpole', 'duration', 20.0)
),
merged AS (
    SELECT c.object_name, c.parameter_id, c.value
    FROM copied c
    WHERE NOT EXISTS (
        SELECT 1 FROM overrides o
        JOIN parameters p ON p.name = o.parameter_name
        WHERE o.object_name = c.object_name AND p.id = c.parameter_id
    )
    UNION ALL
    SELECT o.object_name, p.id, o.value
    FROM overrides o
    JOIN parameters p ON p.name = o.parameter_name
)
INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT go.id, m.parameter_id, m.value
FROM merged m
JOIN game_objects go ON go.name = m.object_name
ON CONFLICT (parameter_id, game_object_id)
DO UPDATE SET value = EXCLUDED.value, updated_at = now();

INSERT INTO prefab_elements(prefab, element)
VALUES
    ('pve_dimension_toad', 'Fire'),
    ('pve_dimension_toad', 'Lightning'),
    ('pve_fire_tadpole', 'Fire'),
    ('pve_lightning_tadpole', 'Lightning')
ON CONFLICT (prefab, element) DO NOTHING;

SELECT setval('game_objects_id_seq', (SELECT max(id) FROM game_objects));

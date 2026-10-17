-- Two new default summons. The carrier's primary card element is Fire; its body and shell
-- both carry Fire + Rock in prefab_elements and on the server. No recipes in the dev model.
-- crater_explosion is a presentation-only timed body with no DB parameters or bot target tags.
-- Shell damage comes from the launching carrier; its own radius is the landing blast radius.

WITH required_objects(name) AS (
    VALUES ('arcane_infantry'), ('crater_carrier'), ('crater_shell')
)
INSERT INTO game_objects(name)
SELECT name FROM required_objects ro
WHERE NOT EXISTS (SELECT 1 FROM game_objects go WHERE go.name = ro.name);

INSERT INTO magics(name, access_type, element, cast_kind, prefab, indicator)
SELECT v.name, 'DEFAULT', v.element, 'Spawn', v.name,
       jsonb_build_object('version', 1, 'layers', jsonb_build_array(
           jsonb_build_object('shape', 'circle', 'origin', 'target',
               'radius', jsonb_build_object('object', v.name, 'parameter', 'radius')),
           jsonb_build_object('shape', 'circle', 'origin', 'target', 'edgeWidth', 0.08,
               'radius', jsonb_build_object('object', v.name, 'parameter', 'attack_range'))))
FROM (VALUES ('arcane_infantry', 'None'), ('crater_carrier', 'Fire')) AS v(name, element)
WHERE NOT EXISTS (SELECT 1 FROM magics m WHERE m.name = v.name);

WITH required_parameters(name) AS (
    VALUES ('hp'), ('damage'), ('attack_interval'), ('attack_range'), ('speed'), ('mass'), ('radius'), ('quantity'), ('range'), ('mana_cost'), ('setup_duration'), ('recovery_duration'), ('magic_id')
)
INSERT INTO parameters(name)
SELECT name FROM required_parameters rp
WHERE NOT EXISTS (SELECT 1 FROM parameters p WHERE p.name = rp.name);

WITH desired_values(object_name, parameter_name, value) AS (
    VALUES
        ('arcane_infantry', 'hp', 360.00),
        ('arcane_infantry', 'damage', 70.00),
        ('arcane_infantry', 'attack_interval', 1.00),
        ('arcane_infantry', 'attack_range', 0.50),
        ('arcane_infantry', 'speed', 1.40),
        ('arcane_infantry', 'mass', 2.00),
        ('arcane_infantry', 'radius', 0.35),
        ('arcane_infantry', 'quantity', 1.00),
        ('arcane_infantry', 'range', 6.00),
        ('arcane_infantry', 'mana_cost', 20.00),
        ('crater_carrier', 'hp', 440.00),
        ('crater_carrier', 'damage', 150.00),
        ('crater_carrier', 'attack_interval', 2.60),
        ('crater_carrier', 'attack_range', 7.00),
        ('crater_carrier', 'speed', 0.65),
        ('crater_carrier', 'mass', 4.00),
        ('crater_carrier', 'radius', 0.50),
        ('crater_carrier', 'quantity', 1.00),
        ('crater_carrier', 'range', 6.00),
        ('crater_carrier', 'mana_cost', 45.00),
        ('crater_carrier', 'setup_duration', 1.20),
        ('crater_carrier', 'recovery_duration', 0.90),
        ('crater_shell', 'speed', 6.00),
        ('crater_shell', 'radius', 1.40)
)
INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT go.id, p.id, dv.value
FROM desired_values dv
JOIN game_objects go ON go.name = dv.object_name
JOIN parameters p ON p.name = dv.parameter_name
ON CONFLICT (parameter_id, game_object_id)
DO UPDATE SET value = EXCLUDED.value, updated_at = now();

INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT go.id, p.id, m.id
FROM magics m
JOIN game_objects go ON go.name = m.name
JOIN parameters p ON p.name = 'magic_id'
WHERE m.name IN ('arcane_infantry', 'crater_carrier')
ON CONFLICT (parameter_id, game_object_id)
DO UPDATE SET value = EXCLUDED.value, updated_at = now();

INSERT INTO prefab_elements(prefab, element)
SELECT v.prefab, v.element
FROM (VALUES
        ('arcane_infantry', 'None'),
        ('crater_carrier', 'Fire'),
        ('crater_carrier', 'Rock'),
        ('crater_shell', 'Fire'),
        ('crater_shell', 'Rock')
) AS v(prefab, element)
WHERE NOT EXISTS (
    SELECT 1 FROM prefab_elements pe WHERE pe.prefab = v.prefab AND pe.element = v.element
);

WITH desired_tags(object_name, tag_name) AS (
    VALUES
        ('arcane_infantry', 'TYPE_Unit'),
        ('arcane_infantry', 'CAT_Small'),
        ('arcane_infantry', 'CAT_Melee'),
        ('crater_carrier', 'TYPE_Unit'),
        ('crater_carrier', 'CAT_Medium'),
        ('crater_carrier', 'CAT_Ranged'),
        ('crater_carrier', 'CAT_AoE'),
        ('crater_shell', 'TYPE_Unit'),
        ('crater_shell', 'CAT_Ranged'),
        ('crater_shell', 'CAT_AoE')
)
INSERT INTO game_object_tags(game_object_id, tag_id)
SELECT go.id, t.id
FROM desired_tags dt
JOIN game_objects go ON go.name = dt.object_name
JOIN tags t ON t.name = dt.tag_name
WHERE NOT EXISTS (
    SELECT 1 FROM game_object_tags got WHERE got.game_object_id = go.id AND got.tag_id = t.id
);

SELECT sync_magic_tags_from_game_objects();

DO $$
DECLARE
    missing_item TEXT;
BEGIN
    SELECT expected.name INTO missing_item
    FROM (VALUES ('arcane_infantry', 'None'), ('crater_carrier', 'Fire')) AS expected(name, element)
    WHERE NOT EXISTS (
        SELECT 1 FROM magics m WHERE m.name = expected.name AND m.element = expected.element
          AND m.cast_kind = 'Spawn' AND m.prefab = expected.name AND m.access_type = 'DEFAULT'
          AND m.indicator->>'version' = '1'
    ) LIMIT 1;
    IF missing_item IS NOT NULL THEN
        RAISE EXCEPTION 'magic % is missing or inconsistent', missing_item;
    END IF;

    SELECT expected.object_name || '.' || expected.parameter_name INTO missing_item
    FROM (VALUES
        ('arcane_infantry', 'hp', 360.00),
        ('arcane_infantry', 'damage', 70.00),
        ('arcane_infantry', 'attack_interval', 1.00),
        ('arcane_infantry', 'attack_range', 0.50),
        ('arcane_infantry', 'speed', 1.40),
        ('arcane_infantry', 'mass', 2.00),
        ('arcane_infantry', 'radius', 0.35),
        ('arcane_infantry', 'quantity', 1.00),
        ('arcane_infantry', 'range', 6.00),
        ('arcane_infantry', 'mana_cost', 20.00),
        ('crater_carrier', 'hp', 440.00),
        ('crater_carrier', 'damage', 150.00),
        ('crater_carrier', 'attack_interval', 2.60),
        ('crater_carrier', 'attack_range', 7.00),
        ('crater_carrier', 'speed', 0.65),
        ('crater_carrier', 'mass', 4.00),
        ('crater_carrier', 'radius', 0.50),
        ('crater_carrier', 'quantity', 1.00),
        ('crater_carrier', 'range', 6.00),
        ('crater_carrier', 'mana_cost', 45.00),
        ('crater_carrier', 'setup_duration', 1.20),
        ('crater_carrier', 'recovery_duration', 0.90),
        ('crater_shell', 'speed', 6.00),
        ('crater_shell', 'radius', 1.40)
    ) AS expected(object_name, parameter_name, value)
    WHERE NOT EXISTS (
        SELECT 1 FROM parameter_values pv
        JOIN game_objects go ON go.id = pv.game_object_id
        JOIN parameters p ON p.id = pv.parameter_id
        WHERE go.name = expected.object_name AND p.name = expected.parameter_name
          AND pv.value = expected.value
    ) LIMIT 1;
    IF missing_item IS NOT NULL THEN
        RAISE EXCEPTION 'parameter % is missing or incorrect', missing_item;
    END IF;

    IF (SELECT count(*) FROM parameter_values pv
        JOIN game_objects go ON go.id = pv.game_object_id
        JOIN parameters p ON p.id = pv.parameter_id AND p.name = 'magic_id'
        JOIN magics m ON m.id = pv.value AND m.name = go.name
        WHERE go.name IN ('arcane_infantry', 'crater_carrier')) <> 2 THEN
        RAISE EXCEPTION 'new summons must reference their magic IDs';
    END IF;

    SELECT expected.prefab || '/' || expected.element INTO missing_item
    FROM (VALUES
        ('arcane_infantry', 'None'),
        ('crater_carrier', 'Fire'),
        ('crater_carrier', 'Rock'),
        ('crater_shell', 'Fire'),
        ('crater_shell', 'Rock')
    ) AS expected(prefab, element)
    WHERE NOT EXISTS (SELECT 1 FROM prefab_elements pe
                      WHERE pe.prefab = expected.prefab AND pe.element = expected.element)
    LIMIT 1;
    IF missing_item IS NOT NULL THEN
        RAISE EXCEPTION 'prefab element % is missing', missing_item;
    END IF;

    SELECT expected.object_name || '/' || expected.tag_name INTO missing_item
    FROM (VALUES
        ('arcane_infantry', 'TYPE_Unit'),
        ('arcane_infantry', 'CAT_Small'),
        ('arcane_infantry', 'CAT_Melee'),
        ('crater_carrier', 'TYPE_Unit'),
        ('crater_carrier', 'CAT_Medium'),
        ('crater_carrier', 'CAT_Ranged'),
        ('crater_carrier', 'CAT_AoE'),
        ('crater_shell', 'TYPE_Unit'),
        ('crater_shell', 'CAT_Ranged'),
        ('crater_shell', 'CAT_AoE')
    ) AS expected(object_name, tag_name)
    WHERE NOT EXISTS (
        SELECT 1 FROM game_object_tags got
        JOIN game_objects go ON go.id = got.game_object_id
        JOIN tags t ON t.id = got.tag_id
        WHERE go.name = expected.object_name AND t.name = expected.tag_name
    ) LIMIT 1;
    IF missing_item IS NOT NULL THEN
        RAISE EXCEPTION 'counter tag % is missing', missing_item;
    END IF;

    IF (SELECT count(DISTINCT m.name) FROM magic_tags mt JOIN magics m ON m.id = mt.magic_id
        WHERE m.name IN ('arcane_infantry', 'crater_carrier')) <> 2 THEN
        RAISE EXCEPTION 'new summons must have derived counter tags';
    END IF;
END $$;

-- Registers the bean_shooter summon (medium ranged Nature, crawls on the ground) and the bean
-- projectile it fires at ground targets only.
--
-- bean_shooter follows aqua_archer's registration: Spawn magic named after its object, so
-- sync_magic_tags_from_game_objects() needs no alias. bean carries the same tags as water_shot.
-- Damage is read from bean_shooter at runtime, so bean has no damage parameter.

WITH required_objects(name) AS (
    VALUES ('bean_shooter'), ('bean')
)
INSERT INTO game_objects(name)
SELECT ro.name
FROM required_objects ro
WHERE NOT EXISTS (
    SELECT 1 FROM game_objects go WHERE go.name = ro.name
);

INSERT INTO magics(name, access_type, element, cast_kind, prefab, indicator)
SELECT 'bean_shooter', am.access_type, 'Nature', 'Spawn', 'bean_shooter',
       '{"version": 1, "layers": [{"shape": "circle", "origin": "target", "radius": {"object": "bean_shooter", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "bean_shooter", "parameter": "attack_range"}, "edgeWidth": 0.08}]}'::jsonb
FROM magics am
WHERE am.name = 'aqua_archer'
  AND NOT EXISTS (SELECT 1 FROM magics m WHERE m.name = 'bean_shooter');

WITH required_parameters(name) AS (
    VALUES ('hp'), ('damage'), ('attack_interval'), ('attack_range'), ('speed'), ('mass'),
           ('radius'), ('quantity'), ('range'), ('mana_cost'), ('magic_id')
)
INSERT INTO parameters(name)
SELECT rp.name
FROM required_parameters rp
WHERE NOT EXISTS (
    SELECT 1 FROM parameters p WHERE p.name = rp.name
);

WITH desired_values(object_name, parameter_name, value) AS (
    VALUES
        ('bean_shooter', 'hp', 260.0),
        ('bean_shooter', 'damage', 130.0),
        ('bean_shooter', 'attack_interval', 2.2),
        ('bean_shooter', 'attack_range', 6.5),
        ('bean_shooter', 'speed', 0.6),
        ('bean_shooter', 'mass', 2.0),
        ('bean_shooter', 'radius', 0.5),
        ('bean_shooter', 'quantity', 1.0),
        ('bean_shooter', 'range', 6.0),
        ('bean_shooter', 'mana_cost', 40.0),
        ('bean_shooter', 'magic_id', (SELECT id::float8 FROM magics WHERE name = 'bean_shooter')),
        ('bean', 'speed', 7.0),
        ('bean', 'radius', 0.3)
)
INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT go.id, p.id, dv.value
FROM desired_values dv
JOIN game_objects go ON go.name = dv.object_name
JOIN parameters p ON p.name = dv.parameter_name
ON CONFLICT (parameter_id, game_object_id)
DO UPDATE SET value = EXCLUDED.value, updated_at = now();

INSERT INTO prefab_elements(prefab, element)
SELECT v.prefab, v.element
FROM (VALUES
    ('bean_shooter', 'Nature'),
    ('bean', 'Nature')
) AS v(prefab, element)
WHERE NOT EXISTS (
    SELECT 1 FROM prefab_elements pe WHERE pe.prefab = v.prefab
);

WITH desired_tags(object_name, tag_name) AS (
    VALUES
        ('bean_shooter', 'TYPE_Unit'),
        ('bean_shooter', 'CAT_Small'),
        ('bean_shooter', 'CAT_Ranged'),
        ('bean', 'TYPE_Unit'),
        ('bean', 'CAT_Ranged')
)
INSERT INTO game_object_tags(game_object_id, tag_id)
SELECT go.id, t.id
FROM desired_tags dt
JOIN game_objects go ON go.name = dt.object_name
JOIN tags t ON t.name = dt.tag_name
WHERE NOT EXISTS (
    SELECT 1
    FROM game_object_tags got
    WHERE got.game_object_id = go.id
      AND got.tag_id = t.id
);

SELECT sync_magic_tags_from_game_objects();

DO
$$
DECLARE
    missing_item TEXT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM magics WHERE name = 'bean_shooter' AND element = 'Nature'
                   AND cast_kind = 'Spawn' AND prefab = 'bean_shooter') THEN
        RAISE EXCEPTION 'magic bean_shooter was not registered';
    END IF;

    SELECT expected.object_name || '.' || expected.parameter_name
    INTO missing_item
    FROM (VALUES
        ('bean_shooter', 'hp', 260.0),
        ('bean_shooter', 'damage', 130.0),
        ('bean_shooter', 'attack_interval', 2.2),
        ('bean_shooter', 'attack_range', 6.5),
        ('bean_shooter', 'speed', 0.6),
        ('bean_shooter', 'mass', 2.0),
        ('bean_shooter', 'radius', 0.5),
        ('bean_shooter', 'quantity', 1.0),
        ('bean_shooter', 'range', 6.0),
        ('bean_shooter', 'mana_cost', 40.0),
        ('bean', 'speed', 7.0),
        ('bean', 'radius', 0.3)
    ) AS expected(object_name, parameter_name, value)
    WHERE NOT EXISTS (
        SELECT 1
        FROM parameter_values pv
        JOIN game_objects go ON go.id = pv.game_object_id
        JOIN parameters p ON p.id = pv.parameter_id
        WHERE go.name = expected.object_name
          AND p.name = expected.parameter_name
          AND pv.value = expected.value
    )
    LIMIT 1;

    IF missing_item IS NOT NULL THEN
        RAISE EXCEPTION 'parameter % is missing or wrong', missing_item;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM parameter_values pv
        JOIN game_objects go ON go.id = pv.game_object_id
        JOIN parameters p ON p.id = pv.parameter_id
        JOIN magics m ON m.name = 'bean_shooter'
        WHERE go.name = 'bean_shooter' AND p.name = 'magic_id' AND pv.value = m.id
    ) THEN
        RAISE EXCEPTION 'bean_shooter.magic_id does not point at the magic';
    END IF;

    SELECT expected.prefab
    INTO missing_item
    FROM (VALUES ('bean_shooter'), ('bean')) AS expected(prefab)
    WHERE NOT EXISTS (
        SELECT 1 FROM prefab_elements pe WHERE pe.prefab = expected.prefab AND pe.element = 'Nature'
    )
    LIMIT 1;

    IF missing_item IS NOT NULL THEN
        RAISE EXCEPTION 'prefab % has no Nature element', missing_item;
    END IF;

    SELECT expected.object_name || '/' || expected.tag_name
    INTO missing_item
    FROM (VALUES
        ('bean_shooter', 'TYPE_Unit'),
        ('bean_shooter', 'CAT_Small'),
        ('bean_shooter', 'CAT_Ranged'),
        ('bean', 'TYPE_Unit'),
        ('bean', 'CAT_Ranged')
    ) AS expected(object_name, tag_name)
    WHERE NOT EXISTS (
        SELECT 1
        FROM game_object_tags got
        JOIN game_objects go ON go.id = got.game_object_id
        JOIN tags t ON t.id = got.tag_id
        WHERE go.name = expected.object_name AND t.name = expected.tag_name
    )
    LIMIT 1;

    IF missing_item IS NOT NULL THEN
        RAISE EXCEPTION 'tag % is missing', missing_item;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM magic_tags mt JOIN magics m ON m.id = mt.magic_id WHERE m.name = 'bean_shooter'
    ) THEN
        RAISE EXCEPTION 'magic bean_shooter has no counter tags';
    END IF;
END
$$;

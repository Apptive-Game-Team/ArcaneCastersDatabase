-- Registers medium rock rubble plus the two rubble-consuming magics.
--
-- earth_call is resource-gated: it converts small remnants to MiniRock and medium remnants to
-- RockGolem. Its counter tags conservatively follow RockGolem, the strongest possible result.
-- rock_blast creates one existing rock_explode prefab at every remnant in the target circle, so
-- its counter tags follow rock_explode. Both magic classes resolve the actual targets in code.

WITH required_objects(name) AS (
    VALUES
        ('medium_rock_remnant'),
        ('earth_call'),
        ('rock_blast')
)
INSERT INTO game_objects(name)
SELECT ro.name
FROM required_objects ro
WHERE NOT EXISTS (
    SELECT 1 FROM game_objects go WHERE go.name = ro.name
);

INSERT INTO magics(name, element, cast_kind, prefab, indicator)
SELECT v.name, v.element, v.cast_kind, v.prefab, v.indicator::jsonb
FROM (VALUES
    (
        'earth_call',
        'Rock',
        'Spawn',
        'earth_call',
        '{"version": 1, "layers": [{"shape": "circle", "origin": "target", "radius": {"object": "earth_call", "parameter": "radius"}}]}'
    ),
    (
        'rock_blast',
        'Rock',
        'Explosion',
        'rock_explode',
        '{"version": 1, "layers": [{"shape": "circle", "origin": "target", "radius": {"object": "rock_blast", "parameter": "radius"}}]}'
    )
) AS v(name, element, cast_kind, prefab, indicator)
WHERE NOT EXISTS (
    SELECT 1 FROM magics m WHERE m.name = v.name
);

UPDATE magics m
SET element = v.element,
    cast_kind = v.cast_kind,
    prefab = v.prefab,
    indicator = v.indicator::jsonb,
    updated_at = now()
FROM (VALUES
    (
        'earth_call',
        'Rock',
        'Spawn',
        'earth_call',
        '{"version": 1, "layers": [{"shape": "circle", "origin": "target", "radius": {"object": "earth_call", "parameter": "radius"}}]}'
    ),
    (
        'rock_blast',
        'Rock',
        'Explosion',
        'rock_explode',
        '{"version": 1, "layers": [{"shape": "circle", "origin": "target", "radius": {"object": "rock_blast", "parameter": "radius"}}]}'
    )
) AS v(name, element, cast_kind, prefab, indicator)
WHERE m.name = v.name;

WITH required_parameters(name) AS (
    VALUES ('mana_cost'), ('range'), ('radius'), ('damage')
)
INSERT INTO parameters(name)
SELECT rp.name
FROM required_parameters rp
WHERE NOT EXISTS (
    SELECT 1 FROM parameters p WHERE p.name = rp.name
);

WITH desired_values(object_name, parameter_name, value) AS (
    VALUES
        ('medium_rock_remnant', 'radius', 1.0),
        ('earth_call', 'mana_cost', 20.0),
        ('earth_call', 'range', 8.0),
        ('earth_call', 'radius', 3.0),
        ('rock_blast', 'mana_cost', 15.0),
        ('rock_blast', 'range', 8.0),
        ('rock_blast', 'radius', 3.0),
        -- Bot targeting uses this as a per-target estimate. Runtime damage remains sourced from
        -- rock_explode, once for every consumed remnant.
        ('rock_blast', 'damage', 100.0)
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
    ('medium_rock_remnant', 'Rock'),
    ('earth_call', 'Rock')
) AS v(prefab, element)
WHERE NOT EXISTS (
    SELECT 1 FROM prefab_elements pe WHERE pe.prefab = v.prefab
);

UPDATE prefab_elements pe
SET element = v.element
FROM (VALUES
    ('medium_rock_remnant', 'Rock'),
    ('earth_call', 'Rock')
) AS v(prefab, element)
WHERE pe.prefab = v.prefab;

WITH desired_tags(object_name, tag_name) AS (
    VALUES
        ('medium_rock_remnant', 'TYPE_Unit'),
        ('earth_call', 'TYPE_Data'),
        ('rock_blast', 'TYPE_Data')
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

INSERT INTO magic_game_object_aliases(magic_name, game_object_name, reason)
SELECT v.magic_name, v.game_object_name, v.reason
FROM (VALUES
    (
        'earth_call',
        'rock_golem',
        'EarthCallMagic conditionally converts MediumRockRemnant to PrefabType.RockGolem'
    ),
    (
        'rock_blast',
        'rock_explode',
        'RockBlastMagic spawns PrefabType.RockExplode at each consumed rock remnant'
    )
) AS v(magic_name, game_object_name, reason)
WHERE NOT EXISTS (
    SELECT 1
    FROM magic_game_object_aliases a
    WHERE a.magic_name = v.magic_name
);

UPDATE magic_game_object_aliases a
SET game_object_name = v.game_object_name,
    reason = v.reason
FROM (VALUES
    (
        'earth_call',
        'rock_golem',
        'EarthCallMagic conditionally converts MediumRockRemnant to PrefabType.RockGolem'
    ),
    (
        'rock_blast',
        'rock_explode',
        'RockBlastMagic spawns PrefabType.RockExplode at each consumed rock remnant'
    )
) AS v(magic_name, game_object_name, reason)
WHERE a.magic_name = v.magic_name;

SELECT sync_magic_tags_from_game_objects();

DO
$$
DECLARE
    missing_item TEXT;
BEGIN
    SELECT expected.name
    INTO missing_item
    FROM (VALUES
        ('earth_call'),
        ('rock_blast')
    ) AS expected(name)
    WHERE NOT EXISTS (
        SELECT 1 FROM magics m WHERE m.name = expected.name
    )
    LIMIT 1;

    IF missing_item IS NOT NULL THEN
        RAISE EXCEPTION 'magic % was not registered', missing_item;
    END IF;

    SELECT expected.object_name || '.' || expected.parameter_name
    INTO missing_item
    FROM (VALUES
        ('medium_rock_remnant', 'radius', 1.0),
        ('earth_call', 'mana_cost', 20.0),
        ('earth_call', 'range', 8.0),
        ('earth_call', 'radius', 3.0),
        ('rock_blast', 'mana_cost', 15.0),
        ('rock_blast', 'range', 8.0),
        ('rock_blast', 'radius', 3.0),
        ('rock_blast', 'damage', 100.0)
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
        FROM game_object_tags got
        JOIN game_objects go ON go.id = got.game_object_id
        JOIN tags t ON t.id = got.tag_id
        WHERE go.name = 'medium_rock_remnant' AND t.name = 'TYPE_Unit'
    ) THEN
        RAISE EXCEPTION 'medium_rock_remnant TYPE_Unit tag is missing';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM game_object_tags got
        JOIN game_objects go ON go.id = got.game_object_id
        JOIN tags t ON t.id = got.tag_id
        WHERE go.name = 'medium_rock_remnant' AND t.name LIKE 'CAT_%'
    ) THEN
        RAISE EXCEPTION 'medium_rock_remnant must not carry a CAT tag';
    END IF;

    SELECT expected.magic_name
    INTO missing_item
    FROM (VALUES
        ('earth_call', 'rock_golem'),
        ('rock_blast', 'rock_explode')
    ) AS expected(magic_name, game_object_name)
    WHERE NOT EXISTS (
        SELECT 1
        FROM magic_game_object_aliases a
        WHERE a.magic_name = expected.magic_name
          AND a.game_object_name = expected.game_object_name
    )
    LIMIT 1;

    IF missing_item IS NOT NULL THEN
        RAISE EXCEPTION 'magic % has the wrong game-object alias', missing_item;
    END IF;

    SELECT m.name
    INTO missing_item
    FROM magics m
    WHERE m.name IN ('earth_call', 'rock_blast')
      AND NOT EXISTS (
          SELECT 1 FROM magic_tags mt WHERE mt.magic_id = m.id
      )
    LIMIT 1;

    IF missing_item IS NOT NULL THEN
        RAISE EXCEPTION 'magic % has no counter tags', missing_item;
    END IF;
END
$$;

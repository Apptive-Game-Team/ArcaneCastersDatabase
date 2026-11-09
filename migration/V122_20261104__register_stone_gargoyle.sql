-- 돌 부족의 중형 공중 유닛. 강하 동작은 Rust 서버에서 구현한다.
-- 번개 정령과 체력·기본 공격력·이동속도·마나가 같고, 근접 강하 후 빠르게 복귀한다.
INSERT INTO game_objects(name)
SELECT 'stone_gargoyle'
WHERE NOT EXISTS (SELECT 1 FROM game_objects WHERE name = 'stone_gargoyle');

INSERT INTO magics(name, access_type, element, cast_kind, prefab, indicator)
SELECT 'stone_gargoyle', 'DEFAULT', 'Rock', 'Spawn', 'stone_gargoyle',
       '{"version":1,"layers":[{"shape":"circle","origin":"target","radius":{"object":"stone_gargoyle","parameter":"radius"}},{"shape":"circle","origin":"target","edgeWidth":0.08,"radius":{"object":"stone_gargoyle","parameter":"attack_range"}}]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM magics WHERE name = 'stone_gargoyle');

WITH required_parameters(name) AS (
    VALUES ('hp'), ('damage'), ('attack_interval'), ('attack_range'), ('speed'),
           ('mass'), ('radius'), ('quantity'), ('range'), ('mana_cost'), ('spawn_height'), ('magic_id')
)
INSERT INTO parameters(name)
SELECT name FROM required_parameters rp
WHERE NOT EXISTS (SELECT 1 FROM parameters p WHERE p.name = rp.name);

WITH desired_values(parameter_name, value) AS (
    VALUES ('hp', 240.0), ('damage', 50.0), ('attack_interval', 1.5),
           ('attack_range', 0.6), ('speed', 2.0), ('mass', 1.0), ('radius', 0.5),
           ('quantity', 1.0), ('range', 6.0), ('mana_cost', 35.0), ('spawn_height', 3.0)
)
INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT go.id, p.id, dv.value
FROM desired_values dv
JOIN parameters p ON p.name = dv.parameter_name
JOIN game_objects go ON go.name = 'stone_gargoyle'
ON CONFLICT (parameter_id, game_object_id)
DO UPDATE SET value = EXCLUDED.value, updated_at = now();

INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT go.id, p.id, m.id
FROM game_objects go
JOIN magics m ON m.name = go.name
JOIN parameters p ON p.name = 'magic_id'
WHERE go.name = 'stone_gargoyle'
ON CONFLICT (parameter_id, game_object_id)
DO UPDATE SET value = EXCLUDED.value, updated_at = now();

INSERT INTO prefab_elements(prefab, element)
SELECT 'stone_gargoyle', 'Rock'
WHERE NOT EXISTS (
    SELECT 1 FROM prefab_elements WHERE prefab = 'stone_gargoyle' AND element = 'Rock'
);

WITH desired_tags(name) AS (
    VALUES ('TYPE_Unit'), ('CAT_Medium'), ('CAT_Melee'), ('CAT_Flying')
)
INSERT INTO game_object_tags(game_object_id, tag_id)
SELECT go.id, t.id
FROM desired_tags dt
JOIN tags t ON t.name = dt.name
JOIN game_objects go ON go.name = 'stone_gargoyle'
WHERE NOT EXISTS (
    SELECT 1 FROM game_object_tags got WHERE got.game_object_id = go.id AND got.tag_id = t.id
);

SELECT sync_magic_tags_from_game_objects();

DO $$
DECLARE
    missing_parameter text;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM magics WHERE name = 'stone_gargoyle' AND access_type = 'DEFAULT'
          AND element = 'Rock' AND cast_kind = 'Spawn' AND prefab = 'stone_gargoyle'
          AND indicator->>'version' = '1'
    ) THEN
        RAISE EXCEPTION 'stone_gargoyle magic is missing or inconsistent';
    END IF;

    SELECT expected.name INTO missing_parameter
    FROM (VALUES
        ('hp', 240.0), ('damage', 50.0), ('attack_interval', 1.5), ('attack_range', 0.6),
        ('speed', 2.0), ('mass', 1.0), ('radius', 0.5), ('quantity', 1.0),
        ('range', 6.0), ('mana_cost', 35.0), ('spawn_height', 3.0)
    ) AS expected(name, value)
    WHERE NOT EXISTS (
        SELECT 1 FROM parameter_values pv
        JOIN parameters p ON p.id = pv.parameter_id
        JOIN game_objects go ON go.id = pv.game_object_id
        WHERE go.name = 'stone_gargoyle' AND p.name = expected.name AND pv.value = expected.value
    ) LIMIT 1;
    IF missing_parameter IS NOT NULL THEN
        RAISE EXCEPTION 'stone_gargoyle parameter % is missing or incorrect', missing_parameter;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM parameter_values pv
        JOIN parameters p ON p.id = pv.parameter_id AND p.name = 'magic_id'
        JOIN game_objects go ON go.id = pv.game_object_id
        JOIN magics m ON m.id = pv.value AND m.name = go.name
        WHERE go.name = 'stone_gargoyle'
    ) OR NOT EXISTS (
        SELECT 1 FROM prefab_elements WHERE prefab = 'stone_gargoyle' AND element = 'Rock'
    ) THEN
        RAISE EXCEPTION 'stone_gargoyle magic ID or Rock element is missing';
    END IF;

    IF (SELECT count(*) FROM game_object_tags got
        JOIN game_objects go ON go.id = got.game_object_id
        JOIN tags t ON t.id = got.tag_id
        WHERE go.name = 'stone_gargoyle'
          AND t.name IN ('TYPE_Unit', 'CAT_Medium', 'CAT_Melee', 'CAT_Flying')) <> 4
    OR (SELECT count(*) FROM magic_tags mt
        JOIN magics m ON m.id = mt.magic_id
        JOIN tags t ON t.id = mt.tag_id
        WHERE m.name = 'stone_gargoyle'
          AND t.name IN ('TYPE_Unit', 'CAT_Medium', 'CAT_Melee', 'CAT_Flying')) <> 4 THEN
        RAISE EXCEPTION 'stone_gargoyle must have unit, medium, melee and flying counter tags';
    END IF;
END $$;

-- 비전 보병(360 HP, 공격력 70, 간격 1초, 이속 1.4)을 기준으로 한 마나 35 근접 유닛이다.
-- 공속 배율은 공격 간격에 역수로 적용한다. 돌골렘의 넉백과 사망 잔해는 유지한다.
INSERT INTO game_objects(name)
SELECT 'electric_spearman'
WHERE NOT EXISTS (SELECT 1 FROM game_objects WHERE name = 'electric_spearman');

INSERT INTO magics(name, access_type, element, cast_kind, prefab, indicator)
SELECT 'electric_spearman', 'DEFAULT', 'Lightning', 'Spawn', 'electric_spearman',
       '{"version":1,"layers":[{"shape":"circle","origin":"target","radius":{"object":"electric_spearman","parameter":"radius"}},{"shape":"circle","origin":"target","edgeWidth":0.08,"radius":{"object":"electric_spearman","parameter":"attack_range"}}]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM magics WHERE name = 'electric_spearman');

WITH required_parameters(name) AS (
    VALUES ('hp'), ('damage'), ('attack_interval'), ('speed'), ('attack_range'),
           ('radius'), ('mass'), ('quantity'), ('range'), ('mana_cost'), ('magic_id')
)
INSERT INTO parameters(name)
SELECT name FROM required_parameters rp
WHERE NOT EXISTS (SELECT 1 FROM parameters p WHERE p.name = rp.name);

WITH desired_values(object_name, parameter_name, value) AS (
    VALUES
        ('arcane_infantry', 'mana_cost', 35.0),
        ('rock_golem', 'hp', 414.0),
        ('rock_golem', 'damage', 63.0),
        ('rock_golem', 'attack_interval', 1.0 / 0.95),
        ('rock_golem', 'speed', 1.19),
        ('rock_golem', 'radius', 0.4),
        ('rock_golem', 'mass', 2.0),
        ('rock_golem', 'mana_cost', 35.0),
        ('electric_spearman', 'hp', 306.0),
        ('electric_spearman', 'damage', 77.0),
        ('electric_spearman', 'attack_interval', 1.0 / 1.10),
        ('electric_spearman', 'speed', 1.82),
        ('electric_spearman', 'attack_range', 0.5),
        ('electric_spearman', 'radius', 0.35),
        ('electric_spearman', 'mass', 2.0),
        ('electric_spearman', 'quantity', 1.0),
        ('electric_spearman', 'range', 6.0),
        ('electric_spearman', 'mana_cost', 35.0)
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
FROM game_objects go
JOIN magics m ON m.name = go.name
JOIN parameters p ON p.name = 'magic_id'
WHERE go.name = 'electric_spearman'
ON CONFLICT (parameter_id, game_object_id)
DO UPDATE SET value = EXCLUDED.value, updated_at = now();

INSERT INTO prefab_elements(prefab, element)
SELECT 'electric_spearman', 'Lightning'
WHERE NOT EXISTS (SELECT 1 FROM prefab_elements
                  WHERE prefab = 'electric_spearman' AND element = 'Lightning');

-- 축소한 돌골렘은 대형 탱커 대신 중형 근접 유닛으로 카운터에 반영한다.
DELETE FROM game_object_tags got USING game_objects go, tags t
WHERE got.game_object_id = go.id AND got.tag_id = t.id
  AND go.name = 'rock_golem' AND t.name IN ('CAT_Large', 'CAT_Tank');

-- 동기화 함수는 태그를 추가만 하므로 기존 마법 태그도 함께 제거한다.
DELETE FROM magic_tags mt USING magics m, tags t
WHERE mt.magic_id = m.id AND mt.tag_id = t.id
  AND m.name = 'rock_golem' AND t.name IN ('CAT_Large', 'CAT_Tank');

WITH desired_tags(object_name, tag_name) AS (
    VALUES ('electric_spearman', 'TYPE_Unit'), ('electric_spearman', 'CAT_Small'),
           ('electric_spearman', 'CAT_Melee'), ('rock_golem', 'TYPE_Unit'),
           ('rock_golem', 'CAT_Medium'), ('rock_golem', 'CAT_Melee')
)
INSERT INTO game_object_tags(game_object_id, tag_id)
SELECT go.id, t.id FROM desired_tags dt
JOIN game_objects go ON go.name = dt.object_name
JOIN tags t ON t.name = dt.tag_name
WHERE NOT EXISTS (SELECT 1 FROM game_object_tags got
                  WHERE got.game_object_id = go.id AND got.tag_id = t.id);

SELECT sync_magic_tags_from_game_objects();

DO $$
DECLARE missing_item text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM magics WHERE name = 'electric_spearman'
        AND access_type = 'DEFAULT' AND purpose = 'PLAYER' AND element = 'Lightning'
        AND cast_kind = 'Spawn' AND prefab = 'electric_spearman' AND indicator->>'version' = '1') THEN
        RAISE EXCEPTION 'electric_spearman magic is missing or inconsistent';
    END IF;

    SELECT expected.object_name || '.' || expected.parameter_name INTO missing_item
    FROM (VALUES
        ('arcane_infantry', 'mana_cost', 35.0),
        ('rock_golem', 'hp', 414.0),
        ('rock_golem', 'damage', 63.0),
        ('rock_golem', 'attack_interval', 1.0 / 0.95),
        ('rock_golem', 'speed', 1.19),
        ('rock_golem', 'radius', 0.4),
        ('rock_golem', 'mass', 2.0),
        ('rock_golem', 'mana_cost', 35.0),
        ('electric_spearman', 'hp', 306.0),
        ('electric_spearman', 'damage', 77.0),
        ('electric_spearman', 'attack_interval', 1.0 / 1.10),
        ('electric_spearman', 'speed', 1.82),
        ('electric_spearman', 'attack_range', 0.5),
        ('electric_spearman', 'radius', 0.35),
        ('electric_spearman', 'mass', 2.0),
        ('electric_spearman', 'quantity', 1.0),
        ('electric_spearman', 'range', 6.0),
        ('electric_spearman', 'mana_cost', 35.0)
    ) AS expected(object_name, parameter_name, value)
    WHERE NOT EXISTS (SELECT 1 FROM parameter_values pv
        JOIN game_objects go ON go.id = pv.game_object_id
        JOIN parameters p ON p.id = pv.parameter_id
        WHERE go.name = expected.object_name AND p.name = expected.parameter_name
          AND abs(pv.value - expected.value) < 0.000001) LIMIT 1;
    IF missing_item IS NOT NULL THEN
        RAISE EXCEPTION 'parameter % is missing or incorrect', missing_item;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM parameter_values pv
        JOIN parameters p ON p.id = pv.parameter_id AND p.name = 'magic_id'
        JOIN game_objects go ON go.id = pv.game_object_id
        JOIN magics m ON m.id = pv.value AND m.name = go.name
        WHERE go.name = 'electric_spearman')
    OR NOT EXISTS (SELECT 1 FROM prefab_elements
        WHERE prefab = 'electric_spearman' AND element = 'Lightning') THEN
        RAISE EXCEPTION 'electric_spearman magic ID or Lightning element is missing';
    END IF;

    SELECT expected.object_name || '/' || expected.tag_name INTO missing_item
    FROM (VALUES ('electric_spearman', 'TYPE_Unit'), ('electric_spearman', 'CAT_Small'),
                 ('electric_spearman', 'CAT_Melee'), ('rock_golem', 'TYPE_Unit'),
                 ('rock_golem', 'CAT_Medium'), ('rock_golem', 'CAT_Melee')) AS expected(object_name, tag_name)
    WHERE NOT EXISTS (SELECT 1 FROM game_object_tags got
        JOIN game_objects go ON go.id = got.game_object_id JOIN tags t ON t.id = got.tag_id
        WHERE go.name = expected.object_name AND t.name = expected.tag_name)
    OR NOT EXISTS (SELECT 1 FROM magic_tags mt
        JOIN magics m ON m.id = mt.magic_id JOIN tags t ON t.id = mt.tag_id
        WHERE m.name = expected.object_name AND t.name = expected.tag_name) LIMIT 1;
    IF missing_item IS NOT NULL THEN
        RAISE EXCEPTION 'counter tag % is missing', missing_item;
    END IF;
    IF EXISTS (SELECT 1 FROM game_object_tags got
        JOIN game_objects go ON go.id = got.game_object_id JOIN tags t ON t.id = got.tag_id
        WHERE go.name = 'rock_golem' AND t.name IN ('CAT_Large', 'CAT_Tank'))
    OR EXISTS (SELECT 1 FROM magic_tags mt
        JOIN magics m ON m.id = mt.magic_id JOIN tags t ON t.id = mt.tag_id
        WHERE m.name = 'rock_golem' AND t.name IN ('CAT_Large', 'CAT_Tank')) THEN
        RAISE EXCEPTION 'rock_golem must no longer be tagged as a large tank';
    END IF;
END $$;

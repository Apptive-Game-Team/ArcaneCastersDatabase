-- main 의 V081_20260908__register_dragon_tower.sql 를 magic-card 모델로 다시 쓴 것이다.
--
-- 분류 C. 달라진 곳은 마법 행, 시전 값, 그리고 range 금지 검사 세 군데다. game object 두 개의
-- 능력치와 counter tag 는 원본 그대로다.
--
--   magics 행       원본은 magics(name, cast_type) 에 'build' 를 넣는다. V085 가 cast_type 을 지웠으므로
--                   (name, element, cast_kind, prefab) 으로 쓴다. cast_kind 'Summon' 과 prefab
--                   'dragon_tower' 는 게임 서버의 DragonTowerPrefabInitializer 가 서 있는 자리다.
--   element         V083 의 규칙대로 조합 {Build, Fire, Shoot} 에서 유일한 원소 카드인 Fire.
--   magic_cards     쓰지 않는다. 조합이 없어지고 읽는 코드도 없다. 원본의 조합 중복 검사도 같은 이유로 뺐다.
--   mana_cost       V084 의 규칙대로 build + shoot + fire 의 mana_cost 합.
--   range           V084 의 규칙대로 시전 종류 game object 'build' 의 range.
--   prefab_elements DragonTowerPrefabInitializer 와 DragonFlamePrefabInitializer 의
--                   setElement(ElementType.FIRE) 에서 읽었다.
--   indicator       명시하지 않는다. V090 의 default 를 받고 V115 가 lane 문서로 덮어쓴다.
--
-- range 금지 검사를 뺀 이유. 원본은 dragon_tower 나 dragon_flame 에 range 행이 생기면 예외를 던진다.
-- 옛 client 의 GameParameterResolver 가 'range' 를 시전 종류 family 'build' 에서 먼저 찾아 마법의
-- range 행이 읽히지 않기 때문이다. 개편에서는 시전 종류 축 자체가 없어져 가릴 family 가 없고, V084 가
-- 모든 마법의 시전 사거리를 마법 이름 game object 의 range 행에 두었다. 그래서 여기서 range 를 쓰는
-- 것이 새 모델에서는 맞고, 원본의 금지 검사는 그대로 옮기면 이 파일 자신이 실패한다. beam_width 금지는
-- 옛 beam 설계의 잔재를 막는 것이라 그대로 남겼다.
--
--   dragon_tower.hp     = ground_tower.hp       x 1.0
--   dragon_flame.damage = electric_tower.damage x 0.6
--   dragon_flame.speed  = fire_shot.speed       x 1.0
--   dragon_flame.radius = fire_shot.radius      x 1.0
--
-- attack_interval 1.5, attack_range 8.0, radius 1.0, duration 20.0, mass 1000000.0 은 원본의 literal
-- 그대로다. attack_range 는 V119 가 18.0 으로 넓힌다.
--
-- dragon_flame 은 마법이 아니라 dragon_tower 가 쏘는 발사체라 magic_game_object_aliases 행이 필요 없고,
-- 다른 field object 처럼 직접 tag 를 단다.

DO
$$
    DECLARE
        missing_reference TEXT;
    BEGIN
        SELECT expected.source || '.' || expected.name
        INTO missing_reference
        FROM (VALUES ('ground_tower', 'hp'),
                     ('electric_tower', 'damage'),
                     ('fire_shot', 'speed'),
                     ('fire_shot', 'radius'),
                     ('build', 'mana_cost'), ('shoot', 'mana_cost'), ('fire', 'mana_cost'),
                     ('build', 'range')) AS expected(source, name)
        WHERE NOT EXISTS (SELECT 1
                          FROM parameter_values parameter_value
                                   JOIN game_objects game_object
                                        ON game_object.id = parameter_value.game_object_id
                                   JOIN parameters parameter
                                        ON parameter.id = parameter_value.parameter_id
                          WHERE game_object.name = expected.source
                            AND parameter.name = expected.name
                            AND parameter_value.value IS NOT NULL)
        LIMIT 1;

        IF missing_reference IS NOT NULL THEN
            RAISE EXCEPTION 'dragon_tower derives a value from %, which does not exist', missing_reference;
        END IF;
    END
$$;

INSERT INTO magics(name, element, cast_kind, prefab)
SELECT 'dragon_tower', 'Fire', 'Summon', 'dragon_tower'
WHERE NOT EXISTS (SELECT 1 FROM magics WHERE name = 'dragon_tower');

UPDATE magics
SET element = 'Fire', cast_kind = 'Summon', prefab = 'dragon_tower'
WHERE name = 'dragon_tower'
  AND (element, cast_kind, prefab) IS DISTINCT FROM ('Fire', 'Summon', 'dragon_tower');

INSERT INTO game_objects(name)
SELECT required.name
FROM (VALUES ('dragon_tower'), ('dragon_flame')) AS required(name)
WHERE NOT EXISTS (SELECT 1 FROM game_objects existing WHERE existing.name = required.name);

INSERT INTO parameters(name)
SELECT required.name
FROM (VALUES ('hp'), ('damage'), ('speed'), ('radius'), ('attack_interval'), ('attack_range'),
             ('duration'), ('mass'), ('mana_cost'), ('range')) AS required(name)
WHERE NOT EXISTS (SELECT 1 FROM parameters parameter WHERE parameter.name = required.name);

WITH source_value(object_name, parameter_name, value) AS (
    SELECT game_object.name, parameter.name, parameter_value.value
    FROM parameter_values parameter_value
             JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
             JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
    WHERE game_object.name IN ('ground_tower', 'electric_tower', 'fire_shot', 'build')
),
     cast_mana_cost AS (
         SELECT SUM(card_mana_cost.value) AS value
         FROM (VALUES ('build'), ('shoot'), ('fire')) AS recipe(card_object)
                  JOIN game_objects card_object ON card_object.name = recipe.card_object
                  JOIN parameters mana_cost_parameter ON mana_cost_parameter.name = 'mana_cost'
                  JOIN parameter_values card_mana_cost
                       ON card_mana_cost.game_object_id = card_object.id
                           AND card_mana_cost.parameter_id = mana_cost_parameter.id
     ),
     seed_values(object_name, parameter_name, value) AS (
         SELECT 'dragon_tower'::TEXT, 'hp'::TEXT,
                (SELECT value FROM source_value WHERE object_name = 'ground_tower' AND parameter_name = 'hp') * 1.0
         UNION ALL SELECT 'dragon_tower'::TEXT, 'attack_interval'::TEXT, 1.5::DOUBLE PRECISION
         UNION ALL SELECT 'dragon_tower'::TEXT, 'attack_range'::TEXT, 8.0::DOUBLE PRECISION
         UNION ALL SELECT 'dragon_tower'::TEXT, 'radius'::TEXT, 1.0::DOUBLE PRECISION
         UNION ALL SELECT 'dragon_tower'::TEXT, 'duration'::TEXT, 20.0::DOUBLE PRECISION
         UNION ALL SELECT 'dragon_tower'::TEXT, 'mass'::TEXT, 1000000.0::DOUBLE PRECISION
         UNION ALL SELECT 'dragon_tower'::TEXT, 'mana_cost'::TEXT, (SELECT value FROM cast_mana_cost)
         UNION ALL SELECT 'dragon_tower'::TEXT, 'range'::TEXT,
                (SELECT value FROM source_value WHERE object_name = 'build' AND parameter_name = 'range')
         UNION ALL SELECT 'dragon_flame'::TEXT, 'damage'::TEXT,
                (SELECT value FROM source_value WHERE object_name = 'electric_tower' AND parameter_name = 'damage') * 0.6
         UNION ALL SELECT 'dragon_flame'::TEXT, 'speed'::TEXT,
                (SELECT value FROM source_value WHERE object_name = 'fire_shot' AND parameter_name = 'speed') * 1.0
         UNION ALL SELECT 'dragon_flame'::TEXT, 'radius'::TEXT,
                (SELECT value FROM source_value WHERE object_name = 'fire_shot' AND parameter_name = 'radius') * 1.0
     )
INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT game_object.id, parameter.id, seed.value
FROM seed_values seed
         JOIN game_objects game_object ON game_object.name = seed.object_name
         JOIN parameters parameter ON parameter.name = seed.parameter_name
ON CONFLICT (parameter_id, game_object_id)
    DO UPDATE SET value = EXCLUDED.value;

INSERT INTO prefab_elements(prefab, element)
VALUES ('dragon_tower', 'Fire'),
       ('dragon_flame', 'Fire')
ON CONFLICT (prefab, element) DO NOTHING;

WITH mapping(game_object_name, tag_name) AS (
    VALUES ('dragon_tower', 'TYPE_Unit'),
           ('dragon_tower', 'CAT_Building'),
           ('dragon_tower', 'CAT_Ranged'),
           ('dragon_tower', 'CAT_AoE'),
           ('dragon_flame', 'TYPE_Unit'),
           ('dragon_flame', 'CAT_Ranged')
),
     required_tags(name) AS (SELECT DISTINCT tag_name FROM mapping),
     inserted_tags AS (
         INSERT INTO tags(name)
             SELECT required.name FROM required_tags required
             WHERE NOT EXISTS (SELECT 1 FROM tags existing WHERE existing.name = required.name)
             RETURNING id, name
     ),
     target_tags AS (
         SELECT id, name FROM inserted_tags
         UNION ALL
         SELECT existing.id, existing.name
         FROM tags existing JOIN required_tags required ON required.name = existing.name
     )
INSERT INTO game_object_tags(game_object_id, tag_id)
SELECT game_object.id, tag.id
FROM mapping
         JOIN game_objects game_object ON game_object.name = mapping.game_object_name
         JOIN target_tags tag ON tag.name = mapping.tag_name
WHERE NOT EXISTS (SELECT 1
                  FROM game_object_tags existing
                  WHERE existing.game_object_id = game_object.id
                    AND existing.tag_id = tag.id);

SELECT sync_magic_tags_from_game_objects();

DO
$$
    DECLARE
        magic_row         RECORD;
        tower_count       INTEGER;
        flame_count       INTEGER;
        tag_count         INTEGER;
        magic_tag_count   INTEGER;
        missing_parameter TEXT;
        derived_gap       TEXT;
    BEGIN
        SELECT element, cast_kind, prefab INTO magic_row FROM magics WHERE name = 'dragon_tower';

        IF magic_row IS NULL OR (magic_row.element, magic_row.cast_kind, magic_row.prefab)
            IS DISTINCT FROM ('Fire', 'Summon', 'dragon_tower') THEN
            RAISE EXCEPTION 'dragon_tower is not registered as (Fire, Summon, dragon_tower)';
        END IF;

        SELECT COUNT(*) INTO tower_count
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
        WHERE game_object.name = 'dragon_tower';

        SELECT COUNT(*) INTO flame_count
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
        WHERE game_object.name = 'dragon_flame';

        -- 원본의 6개에 mana_cost 와 range 가 더해져 8개, dragon_flame 은 원본 그대로 3개다.
        IF tower_count <> 8 OR flame_count <> 3 THEN
            RAISE EXCEPTION 'dragon_tower has % parameter values and dragon_flame %, expected 8 and 3',
                tower_count, flame_count;
        END IF;

        SELECT expected.name
        INTO missing_parameter
        FROM (VALUES ('attack_interval', 1.5), ('attack_range', 8.0), ('radius', 1.0),
                     ('duration', 20.0), ('mass', 1000000.0)) AS expected(name, value)
        WHERE NOT EXISTS (SELECT 1
                          FROM parameter_values parameter_value
                                   JOIN game_objects game_object
                                        ON game_object.id = parameter_value.game_object_id
                                   JOIN parameters parameter
                                        ON parameter.id = parameter_value.parameter_id
                          WHERE game_object.name = 'dragon_tower'
                            AND parameter.name = expected.name
                            AND parameter_value.value = expected.value)
        LIMIT 1;

        IF missing_parameter IS NOT NULL THEN
            RAISE EXCEPTION 'dragon_tower parameter % is missing or holds the wrong value', missing_parameter;
        END IF;

        -- beam_width 는 옛 beam 설계의 잔재라 어느 쪽에도 남으면 안 된다. range 는 개편에서 시전
        -- 사거리의 자리이므로 금지하지 않는다.
        IF EXISTS (SELECT 1
                   FROM parameter_values parameter_value
                            JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                            JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
                   WHERE game_object.name IN ('dragon_tower', 'dragon_flame')
                     AND parameter.name = 'beam_width') THEN
            RAISE EXCEPTION 'dragon_tower or dragon_flame carries a beam_width parameter; use attack_range or radius instead';
        END IF;

        SELECT expected.target || '.' || expected.name || ' <- ' || expected.source
        INTO derived_gap
        FROM (VALUES ('dragon_tower', 'hp', 'ground_tower', 'hp', 1.0),
                     ('dragon_flame', 'damage', 'electric_tower', 'damage', 0.6),
                     ('dragon_flame', 'speed', 'fire_shot', 'speed', 1.0),
                     ('dragon_flame', 'radius', 'fire_shot', 'radius', 1.0))
                 AS expected(target, name, source, source_name, multiplier)
        WHERE NOT EXISTS (SELECT 1
                          FROM parameter_values own_value
                                   JOIN game_objects own ON own.id = own_value.game_object_id
                                   JOIN parameters own_parameter ON own_parameter.id = own_value.parameter_id
                                   JOIN game_objects reference ON reference.name = expected.source
                                   JOIN parameters reference_parameter
                                        ON reference_parameter.name = expected.source_name
                                   JOIN parameter_values reference_value
                                        ON reference_value.game_object_id = reference.id
                                            AND reference_value.parameter_id = reference_parameter.id
                          WHERE own.name = expected.target
                            AND own_parameter.name = expected.name
                            AND ABS(own_value.value - reference_value.value * expected.multiplier) < 1e-6)
        LIMIT 1;

        IF derived_gap IS NOT NULL THEN
            RAISE EXCEPTION 'dragon_tower is not the intended multiple: %', derived_gap;
        END IF;

        SELECT COUNT(*) INTO tag_count
        FROM game_object_tags game_object_tag
                 JOIN game_objects game_object ON game_object.id = game_object_tag.game_object_id
                 JOIN tags tag ON tag.id = game_object_tag.tag_id
        WHERE (game_object.name = 'dragon_tower'
            AND tag.name IN ('TYPE_Unit', 'CAT_Building', 'CAT_Ranged', 'CAT_AoE'))
           OR (game_object.name = 'dragon_flame' AND tag.name IN ('TYPE_Unit', 'CAT_Ranged'));

        IF tag_count <> 6 THEN
            RAISE EXCEPTION 'dragon_tower and dragon_flame carry % of their 6 counter tags', tag_count;
        END IF;

        SELECT COUNT(*) INTO magic_tag_count
        FROM magic_tags magic_tag JOIN magics magic ON magic.id = magic_tag.magic_id
        WHERE magic.name = 'dragon_tower';

        IF magic_tag_count < 4 THEN
            RAISE EXCEPTION 'magic dragon_tower carries only % tags; the name sync did not reach it',
                magic_tag_count;
        END IF;

        IF (SELECT COUNT(*) FROM prefab_elements WHERE prefab IN ('dragon_tower', 'dragon_flame')) <> 2 THEN
            RAISE EXCEPTION 'dragon_tower and dragon_flame do not both carry a Fire element row';
        END IF;
    END
$$;

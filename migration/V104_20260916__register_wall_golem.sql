-- main 의 V077_20260908__register_wall_golem.sql 를 magic-card 모델로 다시 쓴 것이다.
--
-- 분류 C. 원본과 달라진 곳은 마법 행과 시전 값 두 군데뿐이고, game object 의 능력치와 counter tag 는
-- 그대로다.
--
--   magics 행      원본은 magics(name, cast_type) 에 'spawn' 을 넣는다. V085 가 cast_type 을 지웠고
--                  V083 이 element, V087 이 cast_kind 와 prefab 을 NOT NULL 로 만들었으므로
--                  (name, element, cast_kind, prefab) 으로 쓴다. cast_kind 'Spawn' 과
--                  prefab 'wall_golem' 은 게임 서버의 WallGolemPrefabInitializer 가 PrefabType.WallGolem
--                  을 읽는 자리와 같다.
--   element        V083 의 규칙대로 조합에서 가장 많이 든 원소 카드를 쓴다. 조합이
--                  {Rock, Rock, Rock, Spawn} 이므로 Rock 이다.
--   magic_cards    쓰지 않는다. 개편에서 조합이 없어지고 지금도 읽는 코드가 없다. 원본의 조합 중복
--                  검사(DatabaseMagicParser 가 같은 조합을 말없이 덮어쓰는 문제)도 같은 이유로 뺐다.
--   mana_cost      조합이 없어져도 값은 있어야 한다. V084 의 규칙 그대로 조합에 들었던 카드들의
--                  mana_cost 합, 즉 rock x3 + spawn 으로 계산한다.
--   range          V084 의 규칙 그대로 시전 종류 game object 'spawn' 의 range 를 그대로 가져온다.
--   prefab_elements V087 이 만든 표에 prefab 의 원소를 넣는다. 값은 게임 서버의
--                  WallGolemPrefabInitializer.setElement(ElementType.ROCK) 에서 읽었다.
--   indicator      명시하지 않는다. V090 이 걸어 둔 default(조준점에 radius 크기의 채운 원)를 받고,
--                  V115 가 마법의 실제 동작에 맞는 문서로 덮어쓴다.
--
-- 아래 값 유도는 원본 그대로다.
--
--   hp    = magma_spirit.hp   x 1.0
--   damage= rock_golem.damage x 0.8
--   speed = rock_golem.speed  x 0.6
--
-- attack_interval 2.5, mass 10.0, radius 1.8, quantity 1 은 초와 world unit 이라 원본의 literal 그대로다.
--
-- Tags 도 원본 그대로 TYPE_Unit, CAT_Tank, CAT_Large, CAT_Melee 다. 마법과 object 이름이 같아서
-- magic_game_object_aliases 행은 필요 없다.

-- wall_golem 의 hp 는 magma_spirit 없이, damage 와 speed 는 rock_golem 없이 뜻이 없다. NULL 을 쓰기
-- 전에 실패한다. 시전 값 두 개도 같은 이유로 여기서 함께 검사한다.
DO
$$
    DECLARE
        missing_reference TEXT;
    BEGIN
        SELECT expected.source || '.' || expected.name
        INTO missing_reference
        FROM (VALUES ('magma_spirit', 'hp'),
                     ('rock_golem', 'damage'),
                     ('rock_golem', 'speed'),
                     ('rock', 'mana_cost'),
                     ('spawn', 'mana_cost'),
                     ('spawn', 'range')) AS expected(source, name)
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
            RAISE EXCEPTION 'wall_golem derives a value from %, which does not exist',
                missing_reference;
        END IF;
    END
$$;

-- --------------------------------------------------------------------------- 마법
INSERT INTO magics(name, element, cast_kind, prefab)
SELECT 'wall_golem', 'Rock', 'Spawn', 'wall_golem'
WHERE NOT EXISTS (SELECT 1 FROM magics WHERE name = 'wall_golem');

UPDATE magics
SET element   = 'Rock',
    cast_kind = 'Spawn',
    prefab    = 'wall_golem'
WHERE name = 'wall_golem'
  AND (element, cast_kind, prefab) IS DISTINCT FROM ('Rock', 'Spawn', 'wall_golem');

-- ---------------------------------------------------------------------- game object
INSERT INTO game_objects(name)
SELECT 'wall_golem'
WHERE NOT EXISTS (SELECT 1 FROM game_objects WHERE name = 'wall_golem');

INSERT INTO parameters(name)
SELECT required.name
FROM (VALUES ('hp'), ('speed'), ('damage'), ('attack_interval'),
             ('mass'), ('radius'), ('quantity'), ('mana_cost'), ('range')) AS required(name)
WHERE NOT EXISTS (SELECT 1 FROM parameters parameter WHERE parameter.name = required.name);

WITH rock_golem_parameters(name, value) AS (
    SELECT parameter.name, parameter_value.value
    FROM parameter_values parameter_value
             JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
             JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
    WHERE game_object.name = 'rock_golem'
),
     magma_spirit_parameters(name, value) AS (
         SELECT parameter.name, parameter_value.value
         FROM parameter_values parameter_value
                  JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                  JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
         WHERE game_object.name = 'magma_spirit'
     ),
     -- 조합 {Rock, Rock, Rock, Spawn} 의 mana_cost 합. 같은 카드가 세 번 들었으면 세 번 더한다.
     cast_mana_cost AS (
         SELECT SUM(card_mana_cost.value) AS value
         FROM (VALUES ('rock'), ('rock'), ('rock'), ('spawn')) AS recipe(card_object)
                  JOIN game_objects card_object ON card_object.name = recipe.card_object
                  JOIN parameters mana_cost_parameter ON mana_cost_parameter.name = 'mana_cost'
                  JOIN parameter_values card_mana_cost
                       ON card_mana_cost.game_object_id = card_object.id
                           AND card_mana_cost.parameter_id = mana_cost_parameter.id
     ),
     cast_range AS (
         SELECT parameter_value.value
         FROM parameter_values parameter_value
                  JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                  JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
         WHERE game_object.name = 'spawn'
           AND parameter.name = 'range'
     ),
     wall_golem_values(parameter_name, value) AS (
         SELECT 'hp'::TEXT, (SELECT value FROM magma_spirit_parameters WHERE name = 'hp') * 1.0
         UNION ALL
         SELECT 'damage'::TEXT, (SELECT value FROM rock_golem_parameters WHERE name = 'damage') * 0.8
         UNION ALL
         SELECT 'speed'::TEXT, (SELECT value FROM rock_golem_parameters WHERE name = 'speed') * 0.6
         UNION ALL
         SELECT 'attack_interval'::TEXT, 2.5::DOUBLE PRECISION
         UNION ALL
         SELECT 'mass'::TEXT, 10.0::DOUBLE PRECISION
         UNION ALL
         SELECT 'radius'::TEXT, 1.8::DOUBLE PRECISION
         UNION ALL
         SELECT 'quantity'::TEXT, 1.0::DOUBLE PRECISION
         UNION ALL
         SELECT 'mana_cost'::TEXT, (SELECT value FROM cast_mana_cost)
         UNION ALL
         SELECT 'range'::TEXT, (SELECT value FROM cast_range)
     )
INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT game_object.id, parameter.id, seed.value
FROM game_objects game_object
         JOIN wall_golem_values seed ON TRUE
         JOIN parameters parameter ON parameter.name = seed.parameter_name
WHERE game_object.name = 'wall_golem'
ON CONFLICT (parameter_id, game_object_id)
    DO UPDATE SET value = EXCLUDED.value;

-- ------------------------------------------------------------------- prefab 원소
INSERT INTO prefab_elements(prefab, element)
VALUES ('wall_golem', 'Rock')
ON CONFLICT (prefab, element) DO NOTHING;

-- --------------------------------------------------------------------------- tags
WITH required_tags(name) AS (
    VALUES ('TYPE_Unit'), ('CAT_Tank'), ('CAT_Large'), ('CAT_Melee')
),
     inserted_tags AS (
         INSERT INTO tags(name)
             SELECT required.name
             FROM required_tags required
             WHERE NOT EXISTS (SELECT 1 FROM tags tag WHERE tag.name = required.name)
             RETURNING id, name
     ),
     target_tags AS (
         SELECT id, name FROM inserted_tags
         UNION ALL
         SELECT tag.id, tag.name
         FROM tags tag
                  JOIN required_tags required ON required.name = tag.name
     )
INSERT INTO game_object_tags(game_object_id, tag_id)
SELECT game_object.id, tag.id
FROM game_objects game_object
         JOIN target_tags tag ON TRUE
WHERE game_object.name = 'wall_golem'
  AND NOT EXISTS (SELECT 1
                  FROM game_object_tags existing
                  WHERE existing.game_object_id = game_object.id
                    AND existing.tag_id = tag.id);

-- 이것이 없으면 bot 은 wall_golem 을 중립 점수 0.0 으로 보고 아무도 알려주지 않는다.
SELECT sync_magic_tags_from_game_objects();

-- --------------------------------------------------------------------- assertions
DO
$$
    DECLARE
        magic_row         RECORD;
        parameter_count   INTEGER;
        missing_parameter TEXT;
        derived_gap       TEXT;
        expected_mana     DOUBLE PRECISION;
        actual_mana       DOUBLE PRECISION;
        expected_range    DOUBLE PRECISION;
        actual_range      DOUBLE PRECISION;
        tag_count         INTEGER;
        magic_tag_count   INTEGER;
        element_count     INTEGER;
    BEGIN
        SELECT name, element, cast_kind, prefab INTO magic_row FROM magics WHERE name = 'wall_golem';

        IF magic_row IS NULL THEN
            RAISE EXCEPTION 'magic wall_golem was not registered';
        END IF;

        IF (magic_row.element, magic_row.cast_kind, magic_row.prefab)
            IS DISTINCT FROM ('Rock', 'Spawn', 'wall_golem') THEN
            RAISE EXCEPTION 'wall_golem is (%, %, %), expected (Rock, Spawn, wall_golem)',
                magic_row.element, magic_row.cast_kind, magic_row.prefab;
        END IF;

        SELECT COUNT(*)
        INTO parameter_count
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
        WHERE game_object.name = 'wall_golem';

        -- 원본의 7개에 mana_cost 와 range 가 더해져 9개다.
        IF parameter_count <> 9 THEN
            RAISE EXCEPTION 'wall_golem has % parameter values, expected 9', parameter_count;
        END IF;

        SELECT expected.name
        INTO missing_parameter
        FROM (VALUES ('attack_interval', 2.5), ('mass', 10.0), ('radius', 1.8),
                     ('quantity', 1.0)) AS expected(name, value)
        WHERE NOT EXISTS (SELECT 1
                          FROM parameter_values parameter_value
                                   JOIN game_objects game_object
                                        ON game_object.id = parameter_value.game_object_id
                                   JOIN parameters parameter
                                        ON parameter.id = parameter_value.parameter_id
                          WHERE game_object.name = 'wall_golem'
                            AND parameter.name = expected.name
                            AND parameter_value.value = expected.value)
        LIMIT 1;

        IF missing_parameter IS NOT NULL THEN
            RAISE EXCEPTION 'wall_golem parameter % is missing or holds the wrong value',
                missing_parameter;
        END IF;

        -- 유도한 세 행은 이 파일이 약속한 비율로 검사한다.
        SELECT expected.source || '.' || expected.name
        INTO derived_gap
        FROM (VALUES ('magma_spirit', 'hp', 1.0),
                     ('rock_golem', 'damage', 0.8),
                     ('rock_golem', 'speed', 0.6)) AS expected(source, name, multiplier)
        WHERE NOT EXISTS (SELECT 1
                          FROM parameter_values wall_value
                                   JOIN game_objects wall ON wall.id = wall_value.game_object_id
                                   JOIN parameters parameter ON parameter.id = wall_value.parameter_id
                                   JOIN game_objects reference ON reference.name = expected.source
                                   JOIN parameter_values reference_value
                                        ON reference_value.game_object_id = reference.id
                                            AND reference_value.parameter_id = parameter.id
                          WHERE wall.name = 'wall_golem'
                            AND parameter.name = expected.name
                            AND ABS(wall_value.value - reference_value.value * expected.multiplier) < 1e-6)
        LIMIT 1;

        IF derived_gap IS NOT NULL THEN
            RAISE EXCEPTION 'wall_golem is not the intended multiple of %', derived_gap;
        END IF;

        SELECT SUM(card_mana_cost.value)
        INTO expected_mana
        FROM (VALUES ('rock'), ('rock'), ('rock'), ('spawn')) AS recipe(card_object)
                 JOIN game_objects card_object ON card_object.name = recipe.card_object
                 JOIN parameters mana_cost_parameter ON mana_cost_parameter.name = 'mana_cost'
                 JOIN parameter_values card_mana_cost
                      ON card_mana_cost.game_object_id = card_object.id
                          AND card_mana_cost.parameter_id = mana_cost_parameter.id;

        SELECT parameter_value.value
        INTO actual_mana
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                 JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
        WHERE game_object.name = 'wall_golem'
          AND parameter.name = 'mana_cost';

        IF actual_mana IS NULL OR expected_mana IS NULL OR ABS(actual_mana - expected_mana) >= 1e-6 THEN
            RAISE EXCEPTION 'wall_golem mana_cost is %, expected the Rock x3 + Spawn sum %',
                COALESCE(actual_mana::TEXT, '(none)'), COALESCE(expected_mana::TEXT, '(none)');
        END IF;

        SELECT parameter_value.value
        INTO expected_range
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                 JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
        WHERE game_object.name = 'spawn'
          AND parameter.name = 'range';

        SELECT parameter_value.value
        INTO actual_range
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                 JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
        WHERE game_object.name = 'wall_golem'
          AND parameter.name = 'range';

        IF actual_range IS NULL OR expected_range IS NULL OR ABS(actual_range - expected_range) >= 1e-6 THEN
            RAISE EXCEPTION 'wall_golem range is %, expected spawn.range %',
                COALESCE(actual_range::TEXT, '(none)'), COALESCE(expected_range::TEXT, '(none)');
        END IF;

        SELECT COUNT(*)
        INTO tag_count
        FROM game_object_tags game_object_tag
                 JOIN game_objects game_object ON game_object.id = game_object_tag.game_object_id
                 JOIN tags tag ON tag.id = game_object_tag.tag_id
        WHERE game_object.name = 'wall_golem'
          AND tag.name IN ('TYPE_Unit', 'CAT_Tank', 'CAT_Large', 'CAT_Melee');

        IF tag_count <> 4 THEN
            RAISE EXCEPTION 'wall_golem carries % of its 4 counter tags', tag_count;
        END IF;

        SELECT COUNT(*)
        INTO magic_tag_count
        FROM magic_tags magic_tag
                 JOIN magics magic ON magic.id = magic_tag.magic_id
        WHERE magic.name = 'wall_golem';

        IF magic_tag_count < 4 THEN
            RAISE EXCEPTION 'magic wall_golem carries only % tags; the name sync did not reach it',
                magic_tag_count;
        END IF;

        SELECT COUNT(*) INTO element_count FROM prefab_elements WHERE prefab = 'wall_golem';

        IF element_count <> 1 THEN
            RAISE EXCEPTION 'prefab wall_golem carries % element rows, expected 1', element_count;
        END IF;
    END
$$;

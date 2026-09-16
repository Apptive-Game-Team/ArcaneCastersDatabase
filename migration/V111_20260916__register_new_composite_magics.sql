-- main 의 V089_20260914__register_new_composite_magics.sql 를 magic-card 모델로 다시 쓴 것이다.
--
-- 분류 C. 원본은 9월에 추가된 마법 다섯 개를 등록하고 shock_overload 의 조합을 바꾼다.
--
--   magics 행       원본은 magics(name, access_type, cast_type) 로 넣는다. V085 가 cast_type 을 지웠고
--                   V083 이 element, V087 이 cast_kind 와 prefab 을 NOT NULL 로 만들었으므로
--                   (name, access_type, element, cast_kind, prefab) 으로 쓴다.
--   cast_kind/prefab 게임 서버의 구현에서 읽었다. spirit_bomb 은 아무것도 만들지 않고 시전자에게
--                   component 를 붙이고, tidal_warhead 는 무엇에 걸리는지에 따라 prefab 두 개 중
--                   하나를 고른다. 둘 다 행 하나로 표현할 수 없으므로 V087 이 정한 대로 'Code' 이고
--                   prefab 이 없다. 나머지 셋은 이름이 같은 game object 를 만든다.
--   element         V083 의 규칙대로 조합에서 가장 많이 든 원소 카드, 같으면 cards.id 가 작은 쪽이다.
--                   titan_remnant {Build, Rock, Rock} 은 Rock, tidal_warhead {Shoot, Explode, Water} 는
--                   Water, bomb_sprite {Spawn, Drop, Explode, Wind} 는 Wind 로 원소 카드가 하나씩이다.
--                   spirit_bomb {Shoot, Shoot, Lightning, Nature} 은 1:1 이라 Lightning(id 3) 이 Nature(id 5)
--                   를 이기고, boulder_strike {Shoot, Rock, Wind} 도 1:1 이라 Rock(id 4) 이 Wind(id 10) 를
--                   이긴다. shock_overload 는 조합이 바뀌어도 원소 카드가 Lightning 하나뿐이라 그대로다.
--   magic_cards     쓰지 않는다. 조합이 없어지고 읽는 코드도 없다. 원본의 조합 중복 검사도 같은 이유로 뺐다.
--   mana_cost       V084 의 규칙대로 조합에 들었던 카드들의 mana_cost 합. shock_overload 는 조합이
--                   {Explode, Lightning, Lightning} 에서 {Explode, Explode, Lightning} 로 바뀌므로
--                   여기서 다시 계산한다. 원본에서 조합 변경이 뜻하던 마나 비용 변화가 이 한 줄이다.
--   range           V084 의 규칙대로 시전 종류 game object 의 range. titan_remnant 는 build,
--                   spirit_bomb·tidal_warhead·boulder_strike 는 shoot, bomb_sprite 는 spawn 이다.
--                   shock_overload 는 explode 그대로라 건드리지 않는다.
--   user_magics     원본대로 기존 계정 전부에 다섯 개를 준다. V086 이 count 에 default 3 을 걸어 두어서
--                   열을 적지 않아도 카드 3장이 들어간다.
--   prefab_elements 게임 서버의 setElement 호출에서 읽었다. boulder_strike 만 Rock 과 Wind 둘이다.
--   indicator       명시하지 않는다. V090 의 default 를 받고 V115 가 마법마다 덮어쓴다.
--
-- 원본의 never-applied 주석은 옮기지 않았다. 그 사고는 main 의 flyway 이력에서 일어난 일이고
-- magic-card 에는 해당하지 않는다. titan_remnant 의 조합은 원본이 고친 뒤의 {Build, Rock, Rock} 이다.

-- 마나 비용과 사거리를 유도할 카드 행이 전부 있어야 한다. 없으면 합이 조용히 작아지므로 먼저 실패한다.
DO
$$
    DECLARE
        missing_reference TEXT;
    BEGIN
        SELECT expected.source || '.' || expected.name
        INTO missing_reference
        FROM (VALUES ('build', 'mana_cost'), ('shoot', 'mana_cost'), ('spawn', 'mana_cost'),
                     ('drop', 'mana_cost'), ('explode', 'mana_cost'),
                     ('fire', 'mana_cost'), ('water', 'mana_cost'), ('lightning', 'mana_cost'),
                     ('rock', 'mana_cost'), ('nature', 'mana_cost'), ('wind', 'mana_cost'),
                     ('build', 'range'), ('shoot', 'range'), ('spawn', 'range')) AS expected(source, name)
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
            RAISE EXCEPTION 'the composite magics derive a cast value from %, which does not exist',
                missing_reference;
        END IF;
    END
$$;

-- --------------------------------------------------------------------------- 마법
INSERT INTO magics(name, access_type, element, cast_kind, prefab)
SELECT pending.name, 'DEFAULT', pending.element, pending.cast_kind, pending.prefab
FROM (VALUES ('titan_remnant', 'Rock', 'Summon', 'titan_remnant'),
             ('spirit_bomb', 'Lightning', 'Code', NULL),
             ('tidal_warhead', 'Water', 'Code', NULL),
             ('boulder_strike', 'Rock', 'Shot', 'boulder_strike'),
             ('bomb_sprite', 'Wind', 'Spawn', 'bomb_sprite')) pending(name, element, cast_kind, prefab)
WHERE NOT EXISTS (SELECT 1 FROM magics existing WHERE existing.name = pending.name);

UPDATE magics magic
SET access_type = 'DEFAULT',
    element     = expected.element,
    cast_kind   = expected.cast_kind,
    prefab      = expected.prefab
FROM (VALUES ('titan_remnant', 'Rock', 'Summon', 'titan_remnant'),
             ('spirit_bomb', 'Lightning', 'Code', NULL),
             ('tidal_warhead', 'Water', 'Code', NULL),
             ('boulder_strike', 'Rock', 'Shot', 'boulder_strike'),
             ('bomb_sprite', 'Wind', 'Spawn', 'bomb_sprite')) expected(name, element, cast_kind, prefab)
WHERE magic.name = expected.name;

UPDATE magics
SET access_type = 'DEFAULT'
WHERE name = 'shock_overload'
  AND access_type IS DISTINCT FROM 'DEFAULT';

-- 기존 계정은 그러지 않으면 다음 초기화 때에야 DEFAULT 마법을 받는다. 다섯 개를 지금 준다.
-- shock_overload 의 소유는 이미 있으므로 건드리지 않는다.
INSERT INTO user_magics(user_id, magic_id)
SELECT app_user.id, magic.id
FROM users app_user
         CROSS JOIN magics magic
WHERE magic.name IN ('titan_remnant', 'spirit_bomb', 'tidal_warhead', 'boulder_strike', 'bomb_sprite')
ON CONFLICT (user_id, magic_id) DO NOTHING;

-- ----------------------------------------------------------------------------- objects
INSERT INTO game_objects(name)
VALUES ('titan_remnant'),
       ('titan_fist'),
       ('spirit_bomb'),
       ('tidal_warhead'),
       ('ground_tidal_warhead'),
       ('boulder_strike'),
       ('bomb_sprite'),
       ('bomb_sprite_bomb')
ON CONFLICT (name) DO NOTHING;

INSERT INTO parameters(name)
VALUES ('mass'), ('radius'), ('hp'),
       ('speed'), ('damage'), ('attack_interval'), ('attack_range'), ('duration'),
       ('sub_damage'), ('push_force'), ('quantity'), ('mana_cost'), ('range')
ON CONFLICT (name) DO NOTHING;

-- V053 은 이미 적용된 모든 hp 와 damage 행을 10배로 만들었다. 이 migration 은 V053 뒤에 돌므로
-- 아래 hp 와 damage 도 10배가 된 값으로 적는다. speed, radius, duration, mass, force, count 는
-- 원래 단위 그대로다.
WITH configured(game_object_name, parameter_name, value) AS (
    VALUES ('titan_remnant', 'mass', 1000.0),
           ('titan_remnant', 'radius', 1.0),
           ('titan_remnant', 'hp', 400.0),
           ('titan_remnant', 'attack_interval', 2.0),
           ('titan_remnant', 'attack_range', 4.0),
           ('titan_remnant', 'duration', 60.0),
           ('titan_fist', 'radius', 1.25),
           ('titan_fist', 'damage', 120.0),
           ('titan_fist', 'duration', 0.8),
           ('tidal_warhead', 'damage', 240.0),
           ('tidal_warhead', 'speed', 7.0),
           ('tidal_warhead', 'radius', 2.5),
           ('boulder_strike', 'damage', 140.0),
           ('boulder_strike', 'speed', 9.0),
           ('boulder_strike', 'sub_damage', 200.0),
           ('boulder_strike', 'push_force', 7.0),
           ('boulder_strike', 'radius', 0.45),
           ('bomb_sprite', 'mass', 1.0),
           ('bomb_sprite', 'radius', 0.5),
           ('bomb_sprite', 'hp', 200.0),
           ('bomb_sprite', 'speed', 1.5),
           ('bomb_sprite', 'attack_interval', 2.5),
           ('bomb_sprite', 'attack_range', 6.0),
           ('bomb_sprite', 'quantity', 1.0),
           ('bomb_sprite_bomb', 'damage', 180.0),
           ('bomb_sprite_bomb', 'speed', 6.0),
           ('bomb_sprite_bomb', 'radius', 2.0)
)
INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT game_object.id, parameter.id, configured.value
FROM configured
         JOIN game_objects game_object ON game_object.name = configured.game_object_name
         JOIN parameters parameter ON parameter.name = configured.parameter_name
ON CONFLICT (parameter_id, game_object_id)
    DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- --------------------------------------------------------------- 시전 값
--
-- 개편에서 마나 비용과 사거리는 시전 종류 카드가 아니라 마법 이름의 game object 에 산다. spirit_bomb 은
-- prefab 이 없지만 V084 가 모든 마법에 대해 그랬듯 이름이 같은 game object 를 두어 시전 값을 건다.
WITH recipe(magic_name, card_object) AS (
    VALUES ('titan_remnant', 'build'), ('titan_remnant', 'rock'), ('titan_remnant', 'rock'),
           ('spirit_bomb', 'shoot'), ('spirit_bomb', 'shoot'), ('spirit_bomb', 'lightning'),
           ('spirit_bomb', 'nature'),
           ('tidal_warhead', 'shoot'), ('tidal_warhead', 'explode'), ('tidal_warhead', 'water'),
           ('boulder_strike', 'shoot'), ('boulder_strike', 'rock'), ('boulder_strike', 'wind'),
           ('bomb_sprite', 'spawn'), ('bomb_sprite', 'drop'), ('bomb_sprite', 'explode'),
           ('bomb_sprite', 'wind'),
           ('shock_overload', 'explode'), ('shock_overload', 'explode'), ('shock_overload', 'lightning')
),
     cast_family(magic_name, family_object) AS (
         VALUES ('titan_remnant', 'build'),
                ('spirit_bomb', 'shoot'),
                ('tidal_warhead', 'shoot'),
                ('boulder_strike', 'shoot'),
                ('bomb_sprite', 'spawn')
     ),
     mana_cost_per_magic(magic_name, value) AS (
         SELECT recipe.magic_name, SUM(card_mana_cost.value)
         FROM recipe
                  JOIN game_objects card_object ON card_object.name = recipe.card_object
                  JOIN parameters mana_cost_parameter ON mana_cost_parameter.name = 'mana_cost'
                  JOIN parameter_values card_mana_cost
                       ON card_mana_cost.game_object_id = card_object.id
                           AND card_mana_cost.parameter_id = mana_cost_parameter.id
         GROUP BY recipe.magic_name
     ),
     cast_value(magic_name, parameter_name, value) AS (
         SELECT magic_name, 'mana_cost', value FROM mana_cost_per_magic
         UNION ALL
         SELECT cast_family.magic_name, 'range', family_range.value
         FROM cast_family
                  JOIN game_objects family_object ON family_object.name = cast_family.family_object
                  JOIN parameters range_parameter ON range_parameter.name = 'range'
                  JOIN parameter_values family_range
                       ON family_range.game_object_id = family_object.id
                           AND family_range.parameter_id = range_parameter.id
     )
INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT magic_object.id, parameter.id, cast_value.value
FROM cast_value
         JOIN game_objects magic_object ON magic_object.name = cast_value.magic_name
         JOIN parameters parameter ON parameter.name = cast_value.parameter_name
ON CONFLICT (parameter_id, game_object_id)
    DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- ------------------------------------------------------------------- prefab 원소
INSERT INTO prefab_elements(prefab, element)
VALUES ('titan_remnant', 'Rock'),
       ('titan_fist', 'Rock'),
       ('tidal_warhead', 'Water'),
       ('ground_tidal_warhead', 'Water'),
       ('boulder_strike', 'Rock'),
       ('boulder_strike', 'Wind'),
       ('bomb_sprite', 'Wind'),
       ('bomb_sprite_bomb', 'Wind')
ON CONFLICT (prefab, element) DO NOTHING;

-- ----------------------------------------------------------------------- counter tags
WITH mapping(game_object_name, tag_name) AS (
    VALUES ('titan_remnant', 'TYPE_Unit'),
           ('titan_remnant', 'CAT_Building'),
           ('titan_remnant', 'CAT_Ranged'),
           ('titan_remnant', 'CAT_AoE'),
           ('titan_fist', 'TYPE_Data'),
           ('titan_fist', 'CAT_AoE'),
           ('spirit_bomb', 'TYPE_Data'),
           ('spirit_bomb', 'CAT_Ranged'),
           ('tidal_warhead', 'TYPE_Unit'),
           ('tidal_warhead', 'CAT_Ranged'),
           ('tidal_warhead', 'CAT_AoE'),
           ('ground_tidal_warhead', 'TYPE_Unit'),
           ('ground_tidal_warhead', 'CAT_Ranged'),
           ('ground_tidal_warhead', 'CAT_AoE'),
           ('boulder_strike', 'TYPE_Unit'),
           ('boulder_strike', 'CAT_Ranged'),
           ('boulder_strike', 'CAT_CC'),
           ('bomb_sprite', 'TYPE_Unit'),
           ('bomb_sprite', 'CAT_Flying'),
           ('bomb_sprite', 'CAT_Ranged'),
           ('bomb_sprite', 'CAT_AoE'),
           ('bomb_sprite_bomb', 'TYPE_Data'),
           ('bomb_sprite_bomb', 'CAT_AoE')
), required_tags(name) AS (
    SELECT DISTINCT tag_name FROM mapping
), inserted_tags AS (
    INSERT INTO tags(name)
    SELECT required.name
    FROM required_tags required
    WHERE NOT EXISTS (SELECT 1 FROM tags existing WHERE existing.name = required.name)
    RETURNING id, name
), target_tags AS (
    SELECT id, name FROM inserted_tags
    UNION ALL
    SELECT existing.id, existing.name
    FROM tags existing
             JOIN required_tags required ON required.name = existing.name
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

-- --------------------------------------------------------------------------- assertions
DO
$$
DECLARE
    wrong_magic        TEXT;
    missing_parameter  TEXT;
    missing_cast_value TEXT;
    unowned_user_count INTEGER;
    shock_mana         DOUBLE PRECISION;
    expected_shock_mana DOUBLE PRECISION;
BEGIN
    SELECT expected.name
    INTO wrong_magic
    FROM (VALUES ('titan_remnant', 'Rock', 'Summon', 'titan_remnant'),
                 ('spirit_bomb', 'Lightning', 'Code', NULL),
                 ('tidal_warhead', 'Water', 'Code', NULL),
                 ('boulder_strike', 'Rock', 'Shot', 'boulder_strike'),
                 ('bomb_sprite', 'Wind', 'Spawn', 'bomb_sprite')) expected(name, element, cast_kind, prefab)
    WHERE NOT EXISTS (SELECT 1
                      FROM magics magic
                      WHERE magic.name = expected.name
                        AND magic.element = expected.element
                        AND magic.cast_kind = expected.cast_kind
                        AND magic.prefab IS NOT DISTINCT FROM expected.prefab)
    LIMIT 1;

    IF wrong_magic IS NOT NULL THEN
        RAISE EXCEPTION 'magic % is missing or does not carry the element, cast_kind and prefab this file wrote',
            wrong_magic;
    END IF;

    SELECT required.game_object_name || '.' || required.parameter_name
    INTO missing_parameter
    FROM (VALUES ('titan_remnant', 'hp'), ('titan_fist', 'damage'),
                 ('tidal_warhead', 'damage'), ('boulder_strike', 'sub_damage'),
                 ('bomb_sprite', 'hp'), ('bomb_sprite_bomb', 'damage'),
                 ('bomb_sprite_bomb', 'radius')) required(game_object_name, parameter_name)
    WHERE NOT EXISTS (SELECT 1
                      FROM parameter_values parameter_value
                               JOIN game_objects game_object
                                    ON game_object.id = parameter_value.game_object_id
                               JOIN parameters parameter
                                    ON parameter.id = parameter_value.parameter_id
                      WHERE game_object.name = required.game_object_name
                        AND parameter.name = required.parameter_name
                        AND parameter_value.value IS NOT NULL)
    LIMIT 1;

    IF missing_parameter IS NOT NULL THEN
        RAISE EXCEPTION 'required parameter % is missing', missing_parameter;
    END IF;

    -- 마나 비용이나 사거리가 없는 마법은 게임 서버가 시전할 때 ParameterService.getValue 에서
    -- IllegalArgumentException 을 던지고 그 예외가 GameLoop 에 닿아 경기가 끝난다.
    SELECT required.magic_name || '.' || required.parameter_name
    INTO missing_cast_value
    FROM (SELECT magic_name, parameter_name
          FROM (VALUES ('titan_remnant'), ('spirit_bomb'), ('tidal_warhead'),
                       ('boulder_strike'), ('bomb_sprite'), ('shock_overload')) AS magic(magic_name),
               (VALUES ('mana_cost'), ('range')) AS parameter(parameter_name)) required
    WHERE NOT EXISTS (SELECT 1
                      FROM parameter_values parameter_value
                               JOIN game_objects game_object
                                    ON game_object.id = parameter_value.game_object_id
                               JOIN parameters parameter
                                    ON parameter.id = parameter_value.parameter_id
                      WHERE game_object.name = required.magic_name
                        AND parameter.name = required.parameter_name
                        AND parameter_value.value IS NOT NULL)
    LIMIT 1;

    IF missing_cast_value IS NOT NULL THEN
        RAISE EXCEPTION 'cast value % is missing; the game server throws on it and the match ends',
            missing_cast_value;
    END IF;

    -- shock_overload 의 마나 비용이 새 조합 {Explode, Explode, Lightning} 의 합인지 본다. 이것이
    -- 원본의 조합 교체가 개편 모델에서 뜻하는 전부다.
    SELECT SUM(card_mana_cost.value)
    INTO expected_shock_mana
    FROM (VALUES ('explode'), ('explode'), ('lightning')) AS recipe(card_object)
             JOIN game_objects card_object ON card_object.name = recipe.card_object
             JOIN parameters mana_cost_parameter ON mana_cost_parameter.name = 'mana_cost'
             JOIN parameter_values card_mana_cost
                  ON card_mana_cost.game_object_id = card_object.id
                      AND card_mana_cost.parameter_id = mana_cost_parameter.id;

    SELECT parameter_value.value
    INTO shock_mana
    FROM parameter_values parameter_value
             JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
             JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
    WHERE game_object.name = 'shock_overload'
      AND parameter.name = 'mana_cost';

    IF shock_mana IS NULL OR expected_shock_mana IS NULL
        OR ABS(shock_mana - expected_shock_mana) >= 1e-6 THEN
        RAISE EXCEPTION 'shock_overload mana_cost is %, expected the Explode x2 + Lightning sum %',
            COALESCE(shock_mana::TEXT, '(none)'), COALESCE(expected_shock_mana::TEXT, '(none)');
    END IF;

    SELECT COUNT(*)
    INTO unowned_user_count
    FROM users app_user
             CROSS JOIN magics magic
    WHERE magic.name IN ('titan_remnant', 'spirit_bomb', 'tidal_warhead',
                         'boulder_strike', 'bomb_sprite')
      AND NOT EXISTS (SELECT 1
                      FROM user_magics owned
                      WHERE owned.user_id = app_user.id
                        AND owned.magic_id = magic.id);

    IF unowned_user_count > 0 THEN
        RAISE EXCEPTION '% existing user/new magic ownership rows are missing', unowned_user_count;
    END IF;
END
$$;

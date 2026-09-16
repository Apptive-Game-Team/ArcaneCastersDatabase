-- main 의 V082_20260908__register_firework_tower.sql 를 magic-card 모델로 다시 쓴 것이다.
--
-- 분류 C. 달라진 곳은 마법 행, 시전 값, range 금지 검사, 그리고 parameter 개수 검사 네 군데다.
-- game object 두 개의 능력치와 counter tag 는 원본 그대로다.
--
--   magics 행       원본은 magics(name, cast_type) 에 'build' 를 넣는다. V085 가 cast_type 을 지웠으므로
--                   (name, element, cast_kind, prefab) 으로 쓴다. cast_kind 'Summon' 과 prefab
--                   'firework_tower' 는 게임 서버의 FireworkTowerPrefabInitializer 가 서 있는 자리다.
--   element         V083 의 규칙대로 조합 {Build, Drop, Fire} 에서 유일한 원소 카드인 Fire.
--   magic_cards     쓰지 않는다. 조합이 없어지고 읽는 코드도 없다. 원본의 조합 중복 검사도 같은 이유로 뺐다.
--   mana_cost       V084 의 규칙대로 build + drop + fire 의 mana_cost 합.
--   range           V084 의 규칙대로 시전 종류 game object 'build' 의 range.
--   prefab_elements FireworkTowerPrefabInitializer 와 FireworkShellPrefabInitializer 의
--                   setElement(ElementType.FIRE) 에서 읽었다.
--   indicator       명시하지 않는다. V090 의 default 를 받고 V115 가 덮어쓴다.
--
-- range 금지 검사를 뺀 이유는 V108 과 같다. 개편에서는 시전 종류 family 가 없어져 'build' 가 가릴 것이
-- 없고, V084 가 모든 마법의 시전 사거리를 마법 이름 game object 의 range 행에 두었다. 원본의 금지
-- 검사를 그대로 옮기면 이 파일 자신이 실패한다.
--
-- parameter 개수. 원본은 firework_tower 에 6개를 넣고 'expected 6' 으로 검사했는데, 그 6개에 radius 가
-- 빠져 있어서 이 탑을 시전하면 경기가 끝났다. main 은 V092 로 고쳤고 여기서도 V112 가 같은 일을 한다.
-- 원본의 잘못된 개수를 그대로 옮기지 않고, 이 파일이 실제로 쓰는 8개(원본 6 + mana_cost + range)로 적는다.
--
--   firework_tower.hp     = crater.hp x 1.0
--   firework_shell.damage = crater_ember.damage x 1.0
--
-- attack_interval 1.0, attack_range 1.5, attack_offset 3.0, duration 20.0, mass 1000000.0,
-- firework_shell 의 radius 1.5 와 duration 1.0 은 원본의 literal 그대로다. firework_tower.attack_range
-- 와 firework_shell.radius 가 같은 수여야 한다는 계약도 원본의 검사 그대로다.

DO
$$
    DECLARE
        missing_sibling TEXT;
    BEGIN
        SELECT expected.source || '.' || expected.name
        INTO missing_sibling
        FROM (VALUES ('crater', 'hp'),
                     ('crater_ember', 'damage'),
                     ('build', 'mana_cost'), ('drop', 'mana_cost'), ('fire', 'mana_cost'),
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

        IF missing_sibling IS NOT NULL THEN
            RAISE EXCEPTION 'firework_tower derives a value from %, which does not exist', missing_sibling;
        END IF;
    END
$$;

INSERT INTO magics(name, element, cast_kind, prefab)
SELECT 'firework_tower', 'Fire', 'Summon', 'firework_tower'
WHERE NOT EXISTS (SELECT 1 FROM magics WHERE name = 'firework_tower');

UPDATE magics
SET element = 'Fire', cast_kind = 'Summon', prefab = 'firework_tower'
WHERE name = 'firework_tower'
  AND (element, cast_kind, prefab) IS DISTINCT FROM ('Fire', 'Summon', 'firework_tower');

INSERT INTO game_objects(name)
SELECT required.name
FROM (VALUES ('firework_tower'), ('firework_shell')) AS required(name)
WHERE NOT EXISTS (SELECT 1 FROM game_objects existing WHERE existing.name = required.name);

INSERT INTO parameters(name)
SELECT required.name
FROM (VALUES ('hp'), ('damage'), ('radius'), ('attack_interval'), ('attack_range'),
             ('attack_offset'), ('duration'), ('mass'), ('mana_cost'), ('range')) AS required(name)
WHERE NOT EXISTS (SELECT 1 FROM parameters parameter WHERE parameter.name = required.name);

WITH source_value(object_name, parameter_name, value) AS (
    SELECT game_object.name, parameter.name, parameter_value.value
    FROM parameter_values parameter_value
             JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
             JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
    WHERE game_object.name IN ('crater', 'crater_ember', 'build')
),
     cast_mana_cost AS (
         SELECT SUM(card_mana_cost.value) AS value
         FROM (VALUES ('build'), ('drop'), ('fire')) AS recipe(card_object)
                  JOIN game_objects card_object ON card_object.name = recipe.card_object
                  JOIN parameters mana_cost_parameter ON mana_cost_parameter.name = 'mana_cost'
                  JOIN parameter_values card_mana_cost
                       ON card_mana_cost.game_object_id = card_object.id
                           AND card_mana_cost.parameter_id = mana_cost_parameter.id
     ),
     seed_values(object_name, parameter_name, value) AS (
         SELECT 'firework_tower'::TEXT, 'hp'::TEXT,
                (SELECT value FROM source_value WHERE object_name = 'crater' AND parameter_name = 'hp') * 1.0
         UNION ALL SELECT 'firework_tower'::TEXT, 'attack_interval'::TEXT, 1.0::DOUBLE PRECISION
         UNION ALL SELECT 'firework_tower'::TEXT, 'attack_range'::TEXT, 1.5::DOUBLE PRECISION
         UNION ALL SELECT 'firework_tower'::TEXT, 'attack_offset'::TEXT, 3.0::DOUBLE PRECISION
         UNION ALL SELECT 'firework_tower'::TEXT, 'duration'::TEXT, 20.0::DOUBLE PRECISION
         UNION ALL SELECT 'firework_tower'::TEXT, 'mass'::TEXT, 1000000.0::DOUBLE PRECISION
         UNION ALL SELECT 'firework_tower'::TEXT, 'mana_cost'::TEXT, (SELECT value FROM cast_mana_cost)
         UNION ALL SELECT 'firework_tower'::TEXT, 'range'::TEXT,
                (SELECT value FROM source_value WHERE object_name = 'build' AND parameter_name = 'range')
         UNION ALL SELECT 'firework_shell'::TEXT, 'damage'::TEXT,
                (SELECT value FROM source_value WHERE object_name = 'crater_ember' AND parameter_name = 'damage') * 1.0
         UNION ALL SELECT 'firework_shell'::TEXT, 'radius'::TEXT, 1.5::DOUBLE PRECISION
         UNION ALL SELECT 'firework_shell'::TEXT, 'duration'::TEXT, 1.0::DOUBLE PRECISION
     )
INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT game_object.id, parameter.id, seed.value
FROM seed_values seed
         JOIN game_objects game_object ON game_object.name = seed.object_name
         JOIN parameters parameter ON parameter.name = seed.parameter_name
ON CONFLICT (parameter_id, game_object_id)
    DO UPDATE SET value = EXCLUDED.value;

INSERT INTO prefab_elements(prefab, element)
VALUES ('firework_tower', 'Fire'),
       ('firework_shell', 'Fire')
ON CONFLICT (prefab, element) DO NOTHING;

WITH mapping(game_object_name, tag_name) AS (
    VALUES ('firework_tower', 'TYPE_Unit'),
           ('firework_tower', 'CAT_Building'),
           ('firework_tower', 'CAT_Ranged'),
           ('firework_shell', 'TYPE_Unit'),
           ('firework_shell', 'CAT_AoE')
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
        magic_row       RECORD;
        tower_count     INTEGER;
        shell_count     INTEGER;
        tag_count       INTEGER;
        magic_tag_count INTEGER;
        tower_reach     DOUBLE PRECISION;
        shell_radius    DOUBLE PRECISION;
        tower_hp        DOUBLE PRECISION;
        crater_hp       DOUBLE PRECISION;
    BEGIN
        SELECT element, cast_kind, prefab INTO magic_row FROM magics WHERE name = 'firework_tower';

        IF magic_row IS NULL OR (magic_row.element, magic_row.cast_kind, magic_row.prefab)
            IS DISTINCT FROM ('Fire', 'Summon', 'firework_tower') THEN
            RAISE EXCEPTION 'firework_tower is not registered as (Fire, Summon, firework_tower)';
        END IF;

        SELECT COUNT(*) INTO tower_count
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
        WHERE game_object.name = 'firework_tower';

        SELECT COUNT(*) INTO shell_count
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
        WHERE game_object.name = 'firework_shell';

        -- 원본의 6개에 mana_cost 와 range 가 더해져 8개다. radius 는 아직 없고 V112 가 넣는다.
        IF tower_count <> 8 OR shell_count <> 3 THEN
            RAISE EXCEPTION 'firework_tower has % parameter values and firework_shell %, expected 8 and 3',
                tower_count, shell_count;
        END IF;

        SELECT parameter_value.value INTO tower_reach
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                 JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
        WHERE game_object.name = 'firework_tower' AND parameter.name = 'attack_range';

        SELECT parameter_value.value INTO shell_radius
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                 JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
        WHERE game_object.name = 'firework_shell' AND parameter.name = 'radius';

        IF tower_reach IS NULL OR shell_radius IS NULL OR ABS(tower_reach - shell_radius) >= 1e-6 THEN
            RAISE EXCEPTION 'firework_tower attack_range is % but firework_shell radius is %; the client indicator would not match the blast',
                COALESCE(tower_reach::TEXT, '(none)'), COALESCE(shell_radius::TEXT, '(none)');
        END IF;

        SELECT parameter_value.value INTO tower_hp
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                 JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
        WHERE game_object.name = 'firework_tower' AND parameter.name = 'hp';

        SELECT parameter_value.value INTO crater_hp
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                 JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
        WHERE game_object.name = 'crater' AND parameter.name = 'hp';

        IF tower_hp IS NULL OR crater_hp IS NULL OR ABS(tower_hp - crater_hp) >= 1e-6 THEN
            RAISE EXCEPTION 'firework_tower hp is % but crater hp is %; they were meant to match',
                COALESCE(tower_hp::TEXT, '(none)'), COALESCE(crater_hp::TEXT, '(none)');
        END IF;

        SELECT COUNT(*) INTO tag_count
        FROM game_object_tags game_object_tag
                 JOIN game_objects game_object ON game_object.id = game_object_tag.game_object_id
                 JOIN tags tag ON tag.id = game_object_tag.tag_id
        WHERE (game_object.name = 'firework_tower'
            AND tag.name IN ('TYPE_Unit', 'CAT_Building', 'CAT_Ranged'))
           OR (game_object.name = 'firework_shell' AND tag.name IN ('TYPE_Unit', 'CAT_AoE'));

        IF tag_count <> 5 THEN
            RAISE EXCEPTION 'firework_tower and firework_shell carry % of their 5 counter tags', tag_count;
        END IF;

        SELECT COUNT(*) INTO magic_tag_count
        FROM magic_tags magic_tag JOIN magics magic ON magic.id = magic_tag.magic_id
        WHERE magic.name = 'firework_tower';

        IF magic_tag_count < 3 THEN
            RAISE EXCEPTION 'magic firework_tower carries only % tags; the name sync did not reach it',
                magic_tag_count;
        END IF;

        IF (SELECT COUNT(*) FROM prefab_elements WHERE prefab IN ('firework_tower', 'firework_shell')) <> 2 THEN
            RAISE EXCEPTION 'firework_tower and firework_shell do not both carry a Fire element row';
        END IF;
    END
$$;

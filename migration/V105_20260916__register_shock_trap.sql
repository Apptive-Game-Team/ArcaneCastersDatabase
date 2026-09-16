-- main 의 V078_20260908__register_shock_trap.sql 를 magic-card 모델로 다시 쓴 것이다.
--
-- 분류 C. 달라진 곳은 마법 행과 시전 값이고, game object 의 능력치와 counter tag 는 원본 그대로다.
--
--   magics 행       원본은 magics(name, cast_type) 에 'build' 를 넣는다. V085 가 cast_type 을 지웠으므로
--                   (name, element, cast_kind, prefab) 으로 쓴다. cast_kind 'Summon' 과 prefab
--                   'shock_trap' 은 게임 서버의 ShockTrapPrefabInitializer 가 서 있는 자리다.
--   element         V083 의 규칙대로 조합 {Build, Explode, Lightning} 에서 유일한 원소 카드인 Lightning.
--   magic_cards     쓰지 않는다. 조합이 없어지고 읽는 코드도 없다. 원본의 조합 중복 검사도 같은 이유로 뺐다.
--   mana_cost       V084 의 규칙대로 build + explode + lightning 의 mana_cost 합.
--   range           V084 의 규칙대로 시전 종류 game object 'build' 의 range.
--   prefab_elements ShockTrapPrefabInitializer.setElement(ElementType.LIGHTNING) 에서 읽었다.
--   indicator       명시하지 않는다. V090 의 default 를 받고 V115 가 덮어쓴다.
--
--   hp = electric_tower.hp x 1.0
--
-- radius 3.0, trigger_delay 1.0, stun_duration 2.0, attack_interval 8.0, duration 20.0,
-- mass 1000000.0 은 원본의 literal 그대로다. radius 는 V114 가 body 와 effect_radius 로 나누고,
-- stun_duration 은 V113 이 10.0 으로 올린다.

DO
$$
    DECLARE
        missing_reference TEXT;
    BEGIN
        SELECT expected.source || '.' || expected.name
        INTO missing_reference
        FROM (VALUES ('electric_tower', 'hp'),
                     ('build', 'mana_cost'), ('explode', 'mana_cost'), ('lightning', 'mana_cost'),
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
            RAISE EXCEPTION 'shock_trap derives a value from %, which does not exist', missing_reference;
        END IF;
    END
$$;

INSERT INTO magics(name, element, cast_kind, prefab)
SELECT 'shock_trap', 'Lightning', 'Summon', 'shock_trap'
WHERE NOT EXISTS (SELECT 1 FROM magics WHERE name = 'shock_trap');

UPDATE magics
SET element = 'Lightning', cast_kind = 'Summon', prefab = 'shock_trap'
WHERE name = 'shock_trap'
  AND (element, cast_kind, prefab) IS DISTINCT FROM ('Lightning', 'Summon', 'shock_trap');

INSERT INTO game_objects(name)
SELECT 'shock_trap'
WHERE NOT EXISTS (SELECT 1 FROM game_objects WHERE name = 'shock_trap');

INSERT INTO parameters(name)
SELECT required.name
FROM (VALUES ('hp'), ('radius'), ('trigger_delay'), ('stun_duration'),
             ('attack_interval'), ('duration'), ('mass'), ('mana_cost'), ('range')) AS required(name)
WHERE NOT EXISTS (SELECT 1 FROM parameters parameter WHERE parameter.name = required.name);

WITH cast_mana_cost AS (
    SELECT SUM(card_mana_cost.value) AS value
    FROM (VALUES ('build'), ('explode'), ('lightning')) AS recipe(card_object)
             JOIN game_objects card_object ON card_object.name = recipe.card_object
             JOIN parameters mana_cost_parameter ON mana_cost_parameter.name = 'mana_cost'
             JOIN parameter_values card_mana_cost
                  ON card_mana_cost.game_object_id = card_object.id
                      AND card_mana_cost.parameter_id = mana_cost_parameter.id
),
     shock_trap_values(parameter_name, value) AS (
         SELECT 'hp'::TEXT, (SELECT parameter_value.value
                             FROM parameter_values parameter_value
                                      JOIN game_objects game_object
                                           ON game_object.id = parameter_value.game_object_id
                                      JOIN parameters parameter
                                           ON parameter.id = parameter_value.parameter_id
                             WHERE game_object.name = 'electric_tower'
                               AND parameter.name = 'hp') * 1.0
         UNION ALL SELECT 'radius'::TEXT, 3.0::DOUBLE PRECISION
         UNION ALL SELECT 'trigger_delay'::TEXT, 1.0::DOUBLE PRECISION
         UNION ALL SELECT 'stun_duration'::TEXT, 2.0::DOUBLE PRECISION
         UNION ALL SELECT 'attack_interval'::TEXT, 8.0::DOUBLE PRECISION
         UNION ALL SELECT 'duration'::TEXT, 20.0::DOUBLE PRECISION
         UNION ALL SELECT 'mass'::TEXT, 1000000.0::DOUBLE PRECISION
         UNION ALL SELECT 'mana_cost'::TEXT, (SELECT value FROM cast_mana_cost)
         UNION ALL SELECT 'range'::TEXT, (SELECT parameter_value.value
                                          FROM parameter_values parameter_value
                                                   JOIN game_objects game_object
                                                        ON game_object.id = parameter_value.game_object_id
                                                   JOIN parameters parameter
                                                        ON parameter.id = parameter_value.parameter_id
                                          WHERE game_object.name = 'build'
                                            AND parameter.name = 'range')
     )
INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT game_object.id, parameter.id, seed.value
FROM game_objects game_object
         JOIN shock_trap_values seed ON TRUE
         JOIN parameters parameter ON parameter.name = seed.parameter_name
WHERE game_object.name = 'shock_trap'
ON CONFLICT (parameter_id, game_object_id)
    DO UPDATE SET value = EXCLUDED.value;

INSERT INTO prefab_elements(prefab, element)
VALUES ('shock_trap', 'Lightning')
ON CONFLICT (prefab, element) DO NOTHING;

WITH required_tags(name) AS (
    VALUES ('TYPE_Unit'), ('CAT_Building'), ('CAT_CC'), ('CAT_AoE')
),
     inserted_tags AS (
         INSERT INTO tags(name)
             SELECT required.name FROM required_tags required
             WHERE NOT EXISTS (SELECT 1 FROM tags tag WHERE tag.name = required.name)
             RETURNING id, name
     ),
     target_tags AS (
         SELECT id, name FROM inserted_tags
         UNION ALL
         SELECT tag.id, tag.name FROM tags tag JOIN required_tags required ON required.name = tag.name
     )
INSERT INTO game_object_tags(game_object_id, tag_id)
SELECT game_object.id, tag.id
FROM game_objects game_object
         JOIN target_tags tag ON TRUE
WHERE game_object.name = 'shock_trap'
  AND NOT EXISTS (SELECT 1
                  FROM game_object_tags existing
                  WHERE existing.game_object_id = game_object.id
                    AND existing.tag_id = tag.id);

SELECT sync_magic_tags_from_game_objects();

DO
$$
    DECLARE
        magic_row       RECORD;
        parameter_count INTEGER;
        tag_count       INTEGER;
        magic_tag_count INTEGER;
        tower_hp        DOUBLE PRECISION;
        trap_hp         DOUBLE PRECISION;
    BEGIN
        SELECT element, cast_kind, prefab INTO magic_row FROM magics WHERE name = 'shock_trap';

        IF magic_row IS NULL OR (magic_row.element, magic_row.cast_kind, magic_row.prefab)
            IS DISTINCT FROM ('Lightning', 'Summon', 'shock_trap') THEN
            RAISE EXCEPTION 'shock_trap is not registered as (Lightning, Summon, shock_trap)';
        END IF;

        SELECT COUNT(*)
        INTO parameter_count
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
        WHERE game_object.name = 'shock_trap';

        -- 원본의 7개에 mana_cost 와 range 가 더해져 9개다.
        IF parameter_count <> 9 THEN
            RAISE EXCEPTION 'shock_trap has % parameter values, expected 9', parameter_count;
        END IF;

        SELECT parameter_value.value INTO tower_hp
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                 JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
        WHERE game_object.name = 'electric_tower' AND parameter.name = 'hp';

        SELECT parameter_value.value INTO trap_hp
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                 JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
        WHERE game_object.name = 'shock_trap' AND parameter.name = 'hp';

        IF trap_hp IS NULL OR tower_hp IS NULL OR ABS(trap_hp - tower_hp) >= 1e-6 THEN
            RAISE EXCEPTION 'shock_trap hp is % but electric_tower hp is %; they were meant to match',
                COALESCE(trap_hp::TEXT, '(none)'), COALESCE(tower_hp::TEXT, '(none)');
        END IF;

        SELECT COUNT(*) INTO tag_count
        FROM game_object_tags game_object_tag
                 JOIN game_objects game_object ON game_object.id = game_object_tag.game_object_id
                 JOIN tags tag ON tag.id = game_object_tag.tag_id
        WHERE game_object.name = 'shock_trap'
          AND tag.name IN ('TYPE_Unit', 'CAT_Building', 'CAT_CC', 'CAT_AoE');

        IF tag_count <> 4 THEN
            RAISE EXCEPTION 'shock_trap carries % of its 4 counter tags', tag_count;
        END IF;

        SELECT COUNT(*) INTO magic_tag_count
        FROM magic_tags magic_tag JOIN magics magic ON magic.id = magic_tag.magic_id
        WHERE magic.name = 'shock_trap';

        IF magic_tag_count < 4 THEN
            RAISE EXCEPTION 'magic shock_trap carries only % tags; the name sync did not reach it',
                magic_tag_count;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM prefab_elements WHERE prefab = 'shock_trap' AND element = 'Lightning') THEN
            RAISE EXCEPTION 'prefab shock_trap has no Lightning element row';
        END IF;
    END
$$;

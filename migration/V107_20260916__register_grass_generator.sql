-- main 의 V080_20260908__register_grass_generator.sql 를 magic-card 모델로 다시 쓴 것이다.
--
-- 분류 C. 달라진 곳은 마법 행과 시전 값이고, game object 의 능력치와 counter tag 는 원본 그대로다.
--
--   magics 행       원본은 magics(name, cast_type) 에 'build' 를 넣는다. V085 가 cast_type 을 지웠으므로
--                   (name, element, cast_kind, prefab) 으로 쓴다. cast_kind 'Summon' 과 prefab
--                   'grass_generator' 는 게임 서버의 GrassGeneratorPrefabInitializer 가 서 있는 자리다.
--   element         V083 의 규칙대로 조합 {Build, Explode, Nature} 에서 유일한 원소 카드인 Nature.
--   magic_cards     쓰지 않는다. 조합이 없어지고 읽는 코드도 없다. 원본의 조합 중복 검사도 같은 이유로 뺐다.
--   mana_cost       V084 의 규칙대로 build + explode + nature 의 mana_cost 합.
--   range           V084 의 규칙대로 시전 종류 game object 'build' 의 range.
--   prefab_elements GrassGeneratorPrefabInitializer.setElement(ElementType.NATURE) 에서 읽었다.
--   indicator       명시하지 않는다. V090 의 default 를 받고 V115 가 덮어쓴다.
--
--   hp = vine_colony.hp x 1.0
--
-- radius 5.0, attack_interval 1.0, quantity 6.0, duration 25.0, mass 1000000.0 은 원본의 literal
-- 그대로다. leaf_field 는 이미 등록된 game object 라 여기서 건드리지 않는다. radius 는 V114 가 body 와
-- effect_radius 로 나눈다.
--
-- 마지막의 leaf field 개수 검사도 원본 그대로다. GrassSpread 가 CEIL(radius / 1.75) * quantity 칸을
-- 채우므로 5.0 과 6 이면 18칸이고, 상한 24 아래다.

DO
$$
    DECLARE
        missing_reference TEXT;
    BEGIN
        SELECT expected.source || '.' || expected.name
        INTO missing_reference
        FROM (VALUES ('vine_colony', 'hp'),
                     ('build', 'mana_cost'), ('explode', 'mana_cost'), ('nature', 'mana_cost'),
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
            RAISE EXCEPTION 'grass_generator derives a value from %, which does not exist', missing_reference;
        END IF;
    END
$$;

INSERT INTO magics(name, element, cast_kind, prefab)
SELECT 'grass_generator', 'Nature', 'Summon', 'grass_generator'
WHERE NOT EXISTS (SELECT 1 FROM magics WHERE name = 'grass_generator');

UPDATE magics
SET element = 'Nature', cast_kind = 'Summon', prefab = 'grass_generator'
WHERE name = 'grass_generator'
  AND (element, cast_kind, prefab) IS DISTINCT FROM ('Nature', 'Summon', 'grass_generator');

INSERT INTO game_objects(name)
SELECT 'grass_generator'
WHERE NOT EXISTS (SELECT 1 FROM game_objects WHERE name = 'grass_generator');

INSERT INTO parameters(name)
SELECT required.name
FROM (VALUES ('hp'), ('radius'), ('attack_interval'), ('quantity'), ('duration'), ('mass'),
             ('mana_cost'), ('range')) AS required(name)
WHERE NOT EXISTS (SELECT 1 FROM parameters parameter WHERE parameter.name = required.name);

WITH cast_mana_cost AS (
    SELECT SUM(card_mana_cost.value) AS value
    FROM (VALUES ('build'), ('explode'), ('nature')) AS recipe(card_object)
             JOIN game_objects card_object ON card_object.name = recipe.card_object
             JOIN parameters mana_cost_parameter ON mana_cost_parameter.name = 'mana_cost'
             JOIN parameter_values card_mana_cost
                  ON card_mana_cost.game_object_id = card_object.id
                      AND card_mana_cost.parameter_id = mana_cost_parameter.id
),
     seed_values(parameter_name, value) AS (
         SELECT 'hp'::TEXT, (SELECT parameter_value.value
          FROM parameter_values parameter_value
                   JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                   JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
          WHERE game_object.name = 'vine_colony' AND parameter.name = 'hp') * 1.0
         UNION ALL SELECT 'radius'::TEXT, 5.0::DOUBLE PRECISION
         UNION ALL SELECT 'attack_interval'::TEXT, 1.0::DOUBLE PRECISION
         UNION ALL SELECT 'quantity'::TEXT, 6.0::DOUBLE PRECISION
         UNION ALL SELECT 'duration'::TEXT, 25.0::DOUBLE PRECISION
         UNION ALL SELECT 'mass'::TEXT, 1000000.0::DOUBLE PRECISION
         UNION ALL SELECT 'mana_cost'::TEXT, (SELECT value FROM cast_mana_cost)
         UNION ALL SELECT 'range'::TEXT, (SELECT parameter_value.value
          FROM parameter_values parameter_value
                   JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                   JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
          WHERE game_object.name = 'build' AND parameter.name = 'range')
     )
INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT game_object.id, parameter.id, seed.value
FROM game_objects game_object
         JOIN seed_values seed ON TRUE
         JOIN parameters parameter ON parameter.name = seed.parameter_name
WHERE game_object.name = 'grass_generator'
ON CONFLICT (parameter_id, game_object_id)
    DO UPDATE SET value = EXCLUDED.value;

INSERT INTO prefab_elements(prefab, element)
VALUES ('grass_generator', 'Nature')
ON CONFLICT (prefab, element) DO NOTHING;

WITH required_tags(name) AS (
    VALUES ('TYPE_Unit'), ('CAT_Building'), ('CAT_AoE')
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
WHERE game_object.name = 'grass_generator'
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
        source_hp       DOUBLE PRECISION;
        own_hp          DOUBLE PRECISION;
        slot_count      DOUBLE PRECISION;
        field_radius    DOUBLE PRECISION;
        field_quantity  DOUBLE PRECISION;
    BEGIN
        SELECT element, cast_kind, prefab INTO magic_row FROM magics WHERE name = 'grass_generator';

        IF magic_row IS NULL OR (magic_row.element, magic_row.cast_kind, magic_row.prefab)
            IS DISTINCT FROM ('Nature', 'Summon', 'grass_generator') THEN
            RAISE EXCEPTION 'grass_generator is not registered as (Nature, Summon, grass_generator)';
        END IF;

        SELECT COUNT(*)
        INTO parameter_count
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
        WHERE game_object.name = 'grass_generator';

        -- 원본의 6개에 mana_cost 와 range 가 더해져 8개다.
        IF parameter_count <> 8 THEN
            RAISE EXCEPTION 'grass_generator has % parameter values, expected 8', parameter_count;
        END IF;

        SELECT parameter_value.value INTO source_hp
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                 JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
        WHERE game_object.name = 'vine_colony' AND parameter.name = 'hp';

        SELECT parameter_value.value INTO own_hp
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                 JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
        WHERE game_object.name = 'grass_generator' AND parameter.name = 'hp';

        IF own_hp IS NULL OR source_hp IS NULL OR ABS(own_hp - source_hp) >= 1e-6 THEN
            RAISE EXCEPTION 'grass_generator hp is % but vine_colony hp is %; they were meant to match',
                COALESCE(own_hp::TEXT, '(none)'), COALESCE(source_hp::TEXT, '(none)');
        END IF;

        SELECT COUNT(*) INTO tag_count
        FROM game_object_tags game_object_tag
                 JOIN game_objects game_object ON game_object.id = game_object_tag.game_object_id
                 JOIN tags tag ON tag.id = game_object_tag.tag_id
        WHERE game_object.name = 'grass_generator'
          AND tag.name IN ('TYPE_Unit', 'CAT_Building', 'CAT_AoE');

        IF tag_count <> 3 THEN
            RAISE EXCEPTION 'grass_generator carries % of its 3 counter tags', tag_count;
        END IF;

        SELECT COUNT(*) INTO magic_tag_count
        FROM magic_tags magic_tag JOIN magics magic ON magic.id = magic_tag.magic_id
        WHERE magic.name = 'grass_generator';

        IF magic_tag_count < 3 THEN
            RAISE EXCEPTION 'magic grass_generator carries only % tags; the name sync did not reach it',
                magic_tag_count;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM prefab_elements WHERE prefab = 'grass_generator' AND element = 'Nature') THEN
            RAISE EXCEPTION 'prefab grass_generator has no Nature element row';
        END IF;

        -- GrassSpread 가 CEIL(radius / RING_SPACING) * quantity 칸을 채우고 칸마다 leaf field 를
        -- 하나 심는다. 1.75 는 게임 서버의 GrassSpread.RING_SPACING 이다.
        SELECT parameter_value.value INTO field_radius
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                 JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
        WHERE game_object.name = 'grass_generator' AND parameter.name = 'radius';

        SELECT parameter_value.value INTO field_quantity
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                 JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
        WHERE game_object.name = 'grass_generator' AND parameter.name = 'quantity';

        slot_count := CEIL(field_radius / 1.75) * field_quantity;

        IF slot_count > 24 THEN
            RAISE EXCEPTION 'grass_generator would hold % leaf fields at once (radius %, quantity %); lower one of them',
                slot_count, field_radius, field_quantity;
        END IF;
    END
$$;

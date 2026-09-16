-- main 의 V076_20260908__rebalance_magma_spirit.sql 를 magic-card 모델로 다시 쓴 것이다.
--
-- 분류 C. 원본은 두 가지를 한다.
--
--   1. magma_spirit 의 조합에 Fire 카드를 한 장 더해 {Explode, Fire, Fire, Rock, Spawn} 다섯 장으로
--      만든다. V043 이 지웠던 두 번째 Fire 를 되돌리는 것이고, 목적은 마나 비용을 올리는 것이다.
--      옛 모델에서는 PlayerData 가 낸 카드들의 mana_cost 를 더했으므로 카드를 더하면 값이 따라 올랐다.
--   2. magma_spirit 의 hp 를 2000 에서 1750 으로 내린다.
--
-- magic-card 에는 조합이 없다. 카드 한 장이 마법 하나이고, 마나 비용은 V084 가 마법 이름의
-- game object 에 mana_cost parameter 행으로 박아 둔 값이다. 그래서 1 은 magic_cards 에 행을 넣는
-- 대신 V084 와 같은 규칙으로 magma_spirit 의 mana_cost 를 다섯 장 기준으로 다시 계산한다.
-- 카드별 mana_cost 행은 V084 가 "옛 키는 그대로 둔다"고 적은 대로 fire, rock, explode, spawn
-- game object 에 그대로 남아 있다.
--
-- magic_cards 에는 아무것도 쓰지 않는다. 그 표는 개편에서 없어지고, 지금도 읽는 코드가 없다.
-- 2 는 parameter_values 한 행이라 원본 그대로다.
--
-- 다시 계산하는 방식이라 두 번 돌려도 값이 두 배가 되지 않는다.

-- 다섯 장 전부에 mana_cost 가 있어야 합이 의미를 갖는다. 없는 카드가 있으면 LEFT JOIN 없이
-- 합이 조용히 작아지므로 먼저 실패한다.
DO
$$
    DECLARE
        unpriced_cards TEXT;
    BEGIN
        SELECT STRING_AGG(recipe.card_object, ', ' ORDER BY recipe.card_object)
        INTO unpriced_cards
        FROM (VALUES ('explode'), ('fire'), ('rock'), ('spawn')) AS recipe(card_object)
        WHERE NOT EXISTS (SELECT 1
                          FROM parameter_values card_mana_cost
                                   JOIN game_objects card_object
                                        ON card_object.id = card_mana_cost.game_object_id
                                   JOIN parameters mana_cost_parameter
                                        ON mana_cost_parameter.id = card_mana_cost.parameter_id
                          WHERE card_object.name = recipe.card_object
                            AND mana_cost_parameter.name = 'mana_cost'
                            AND card_mana_cost.value IS NOT NULL);

        IF unpriced_cards IS NOT NULL THEN
            RAISE EXCEPTION 'these card objects have no mana_cost row; the five-card sum would be wrong: %',
                unpriced_cards;
        END IF;
    END
$$;

-- 이 파일이 쓰여진 시점의 값을 기록한다. 예외가 아니라 경고인 것은 migration rule 3 때문이다.
DO
$$
    DECLARE
        current_hp DOUBLE PRECISION;
    BEGIN
        SELECT parameter_value.value
        INTO current_hp
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                 JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
        WHERE game_object.name = 'magma_spirit'
          AND parameter.name = 'hp';

        IF current_hp IS NULL THEN
            RAISE EXCEPTION 'magma_spirit has no hp value to lower';
        END IF;

        IF current_hp <> 2000 AND current_hp <> 1750 THEN
            RAISE WARNING 'magma_spirit hp was %, not the 2000 this migration was written against; 1750 was chosen from a 2000 baseline',
                current_hp;
        END IF;
    END
$$;

-- ------------------------------------------------------- 다섯 장짜리 마나 비용
--
-- {Explode, Fire, Fire, Rock, Spawn} 의 mana_cost 합. 같은 카드가 두 번 들었으면 두 번 더한다는
-- V084 의 규칙을 그대로 따른다.
WITH five_card_recipe(card_object) AS (VALUES ('explode'), ('fire'), ('fire'), ('rock'), ('spawn')),
     five_card_mana_cost AS (SELECT SUM(card_mana_cost.value) AS value
                             FROM five_card_recipe recipe
                                      JOIN game_objects card_object ON card_object.name = recipe.card_object
                                      JOIN parameters mana_cost_parameter ON mana_cost_parameter.name = 'mana_cost'
                                      JOIN parameter_values card_mana_cost
                                           ON card_mana_cost.game_object_id = card_object.id
                                               AND card_mana_cost.parameter_id = mana_cost_parameter.id)
INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT magma_spirit.id, mana_cost_parameter.id, five_card_mana_cost.value
FROM game_objects magma_spirit
         JOIN parameters mana_cost_parameter ON mana_cost_parameter.name = 'mana_cost'
         CROSS JOIN five_card_mana_cost
WHERE magma_spirit.name = 'magma_spirit'
ON CONFLICT (parameter_id, game_object_id)
    DO UPDATE SET value      = EXCLUDED.value,
                  updated_at = NOW();

-- ------------------------------------------------------------------------ hp
UPDATE parameter_values pv
SET value = updates.value
FROM game_objects go
JOIN (
    VALUES
        ('magma_spirit', 'hp', 1750)
) AS updates(game_object_name, parameter_name, value)
    ON updates.game_object_name = go.name
JOIN parameters p
    ON p.name = updates.parameter_name
WHERE pv.game_object_id = go.id
  AND pv.parameter_id = p.id;

DO
$$
    DECLARE
        current_hp        DOUBLE PRECISION;
        current_mana_cost DOUBLE PRECISION;
        expected_mana_cost DOUBLE PRECISION;
    BEGIN
        SELECT parameter_value.value
        INTO current_hp
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                 JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
        WHERE game_object.name = 'magma_spirit'
          AND parameter.name = 'hp';

        IF current_hp IS DISTINCT FROM 1750::DOUBLE PRECISION THEN
            RAISE EXCEPTION 'magma_spirit hp is %, expected 1750',
                COALESCE(current_hp::TEXT, '(none)');
        END IF;

        SELECT parameter_value.value
        INTO current_mana_cost
        FROM parameter_values parameter_value
                 JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                 JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
        WHERE game_object.name = 'magma_spirit'
          AND parameter.name = 'mana_cost';

        SELECT SUM(card_mana_cost.value)
        INTO expected_mana_cost
        FROM (VALUES ('explode'), ('fire'), ('fire'), ('rock'), ('spawn')) AS recipe(card_object)
                 JOIN game_objects card_object ON card_object.name = recipe.card_object
                 JOIN parameters mana_cost_parameter ON mana_cost_parameter.name = 'mana_cost'
                 JOIN parameter_values card_mana_cost
                      ON card_mana_cost.game_object_id = card_object.id
                          AND card_mana_cost.parameter_id = mana_cost_parameter.id;

        IF current_mana_cost IS NULL OR expected_mana_cost IS NULL
            OR ABS(current_mana_cost - expected_mana_cost) >= 1e-6 THEN
            RAISE EXCEPTION 'magma_spirit mana_cost is %, expected the five-card sum %',
                COALESCE(current_mana_cost::TEXT, '(none)'), COALESCE(expected_mana_cost::TEXT, '(none)');
        END IF;

        RAISE NOTICE 'magma_spirit costs % mana and holds % hp', current_mana_cost, current_hp;
    END
$$;

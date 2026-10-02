-- PVP에서 역할 대비 효율이 크게 벗어난 소환수와 건물의 수치를 조정한다.
--
-- tree_golem은 같은 20 DPS 전열인 rock_golem보다 마나가 5 낮지만 체력이 300 대 1000이라
-- 자체 회복(초당 약 0.67)을 감안해도 전열을 맡지 못한다. electric_tower는 사거리 5에서
-- 주 대상 50 DPS와 연쇄 피해를 주면서 15 마나라 동급 건물보다 효율이 높다. sea_serpent는
-- 80 마나 소환수인데 체력 160, 단일 대상 기준 약 4.57 DPS라 전투 기여도가 지나치게 낮다.
--
-- no-tags: 기존 game_objects와 magics의 parameter_values만 조정한다.

CREATE TEMP TABLE pvp_balance (
    object_name   text             NOT NULL,
    parameter_name text            NOT NULL,
    desired_value double precision NOT NULL,
    PRIMARY KEY (object_name, parameter_name)
) ON COMMIT DROP;

INSERT INTO pvp_balance(object_name, parameter_name, desired_value)
VALUES
    ('tree_golem', 'hp', 450),
    ('electric_tower', 'mana_cost', 20),
    ('sea_serpent', 'hp', 300),
    ('sea_serpent', 'damage', 60);

-- 이름이나 parameter 행이 어긋나면 일부 값만 조용히 남지 않도록 적용 전에 중단한다.
DO
$$
    DECLARE
        missing text;
    BEGIN
        SELECT string_agg(format('%s.%s', balance.object_name, balance.parameter_name),
                          ', ' ORDER BY balance.object_name, balance.parameter_name)
        INTO missing
        FROM pvp_balance balance
        WHERE NOT EXISTS (SELECT 1
                          FROM game_objects object
                                   JOIN parameter_values stored ON stored.game_object_id = object.id
                                   JOIN parameters parameter ON parameter.id = stored.parameter_id
                          WHERE object.name = balance.object_name
                            AND parameter.name = balance.parameter_name);

        IF missing IS NOT NULL THEN
            RAISE EXCEPTION 'PVP balance parameter row missing for: %', missing;
        END IF;
    END
$$;

-- 이미 목표값이면 updated_at을 다시 올리지 않아 재실행해도 안전하다.
-- 변경된 magic의 updated_at도 함께 올려 lobby/client의 magic 목록 캐시를 갱신한다.
WITH changed AS (
    UPDATE parameter_values stored
        SET value = balance.desired_value,
            updated_at = now()
        FROM pvp_balance balance
            JOIN game_objects object ON object.name = balance.object_name
            JOIN parameters parameter ON parameter.name = balance.parameter_name
        WHERE stored.game_object_id = object.id
          AND stored.parameter_id = parameter.id
          AND stored.value IS DISTINCT FROM balance.desired_value
        RETURNING balance.object_name
)
UPDATE magics magic
SET updated_at = now()
WHERE magic.name IN (SELECT DISTINCT object_name FROM changed);

DO
$$
    DECLARE
        wrong text;
    BEGIN
        SELECT string_agg(
                       format('%s.%s=%s(expected %s)', balance.object_name,
                              balance.parameter_name, stored.value, balance.desired_value),
                       ', ' ORDER BY balance.object_name, balance.parameter_name)
        INTO wrong
        FROM pvp_balance balance
                 JOIN game_objects object ON object.name = balance.object_name
                 JOIN parameters parameter ON parameter.name = balance.parameter_name
                 JOIN parameter_values stored ON stored.game_object_id = object.id
            AND stored.parameter_id = parameter.id
        WHERE stored.value IS DISTINCT FROM balance.desired_value;

        IF wrong IS NOT NULL THEN
            RAISE EXCEPTION 'PVP balance values not applied for: %', wrong;
        END IF;
    END
$$;

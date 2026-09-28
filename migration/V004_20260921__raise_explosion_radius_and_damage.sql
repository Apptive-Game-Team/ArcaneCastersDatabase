-- 폭발 magic 세 개(magma_explosion, electric_explode, shock_overload)의 radius 를 0.5 에서 1.5 로,
-- damage 를 80 에서 100 으로 올린다. 셋 다 radius 0.5 짜리라 한 자리에서 터지는 것처럼 보이고,
-- overgrowth(1.5), sand_storm(2), razor_gale(2.5) 같은 다른 범위 magic 보다 훨씬 좁다.
--
-- radius 만 1.5 로 올려도 넓이는 9배가 된다. damage 는 25%만 올려서 한 방의 세기보다 맞는 대상
-- 수로 세지게 한다. 자세한 근거는 issue #29 를 참고한다.
--
-- water_explosion 은 radius 가 이미 1.5 라 건드리지 않는다. fire_explode, leaf_explode,
-- rock_explode, water_explode 도 radius 가 0.5 지만 dev 의 어떤 magic 도 이 prefab 을 띄우지
-- 않으므로 그대로 둔다.
--
-- radius 와 damage 는 parameters.name 과 game_objects.name 을 거쳐 parameter_values 에 붙어
-- 있고, game server 가 그 이름으로 읽는다. id 값에 의존하지 않도록 이름으로 join 한다.
--
-- no-tags: game_objects 와 magics 에 새 행을 넣지 않는다. 기존 행의 value 만 바꾼다.

CREATE TEMP TABLE explosion_tier (
    game_object_name text PRIMARY KEY,
    radius           double precision NOT NULL,
    damage           double precision NOT NULL
) ON COMMIT DROP;

INSERT INTO explosion_tier(game_object_name, radius, damage)
VALUES
    ('magma_explosion', 1.5, 100),
    ('electric_explode', 1.5, 100),
    ('shock_overload', 1.5, 100);

-- 이름이 하나라도 어긋나면 그 game object 만 조용히 옛 값으로 남는다. 먼저 막는다.
DO
$$
    DECLARE
        missing text;
    BEGIN
        SELECT string_agg(tier.game_object_name, ', ' ORDER BY tier.game_object_name)
        INTO missing
        FROM explosion_tier tier
        WHERE NOT EXISTS (SELECT 1
                          FROM game_objects object
                                   JOIN parameter_values stored ON stored.game_object_id = object.id
                                   JOIN parameters parameter ON parameter.id = stored.parameter_id
                              AND parameter.name = 'radius'
                          WHERE object.name = tier.game_object_name)
           OR NOT EXISTS (SELECT 1
                          FROM game_objects object
                                   JOIN parameter_values stored ON stored.game_object_id = object.id
                                   JOIN parameters parameter ON parameter.id = stored.parameter_id
                              AND parameter.name = 'damage'
                          WHERE object.name = tier.game_object_name);

        IF missing IS NOT NULL THEN
            RAISE EXCEPTION 'radius or damage parameter_values row missing for: %', missing;
        END IF;
    END
$$;

-- value 가 이미 같으면 아무것도 바꾸지 않는다. 그래서 다시 돌려도 updated_at 이 또 올라가지 않는다
-- (migration rule 3).
UPDATE parameter_values stored
SET value      = tier.radius,
    updated_at = now()
FROM explosion_tier tier
    JOIN game_objects object ON object.name = tier.game_object_name
    JOIN parameters parameter ON parameter.name = 'radius'
WHERE stored.game_object_id = object.id
  AND stored.parameter_id = parameter.id
  AND stored.value IS DISTINCT FROM tier.radius;

UPDATE parameter_values stored
SET value      = tier.damage,
    updated_at = now()
FROM explosion_tier tier
    JOIN game_objects object ON object.name = tier.game_object_name
    JOIN parameters parameter ON parameter.name = 'damage'
WHERE stored.game_object_id = object.id
  AND stored.parameter_id = parameter.id
  AND stored.value IS DISTINCT FROM tier.damage;

-- 끝난 뒤 세 game object 모두 radius 1.5, damage 100 인지 확인한다.
DO
$$
    DECLARE
        wrong text;
    BEGIN
        SELECT string_agg(format('%s: radius=%s(expected %s) damage=%s(expected %s)',
                                  tier.game_object_name, radius_value.value, tier.radius,
                                  damage_value.value, tier.damage),
                          ', ' ORDER BY tier.game_object_name)
        INTO wrong
        FROM explosion_tier tier
                 JOIN game_objects object ON object.name = tier.game_object_name
                 JOIN parameters radius_parameter ON radius_parameter.name = 'radius'
                 JOIN parameter_values radius_value ON radius_value.game_object_id = object.id
            AND radius_value.parameter_id = radius_parameter.id
                 JOIN parameters damage_parameter ON damage_parameter.name = 'damage'
                 JOIN parameter_values damage_value ON damage_value.game_object_id = object.id
            AND damage_value.parameter_id = damage_parameter.id
        WHERE radius_value.value IS DISTINCT FROM tier.radius
           OR damage_value.value IS DISTINCT FROM tier.damage;

        IF wrong IS NOT NULL THEN
            RAISE EXCEPTION 'explosion radius/damage not applied for: %', wrong;
        END IF;

        RAISE NOTICE '% explosion magics now carry radius 1.5 and damage 100', (SELECT count(*) FROM explosion_tier);
    END
$$;

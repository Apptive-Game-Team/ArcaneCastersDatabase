-- wind_totem 의 push_range_y 이름이 축과 어긋나 있었다. game server 의 지면은 X-Z 평면이고
-- Y 는 높이인데, push_range_y 의 값 3 이 그대로 높이 축에 실려서 밀리는 범위가 6 x 3 이 아니라
-- 6 x 1 이었다. 진짜 지면 깊이 1.0f 는 코드에 하드코딩돼 있었다. 자세한 근거는 issue #31,
-- ArcaneCastersGame#41 을 참고한다.
--
-- 고치는 내용:
--   1. parameters 에 push_range_z 를 새로 넣는다 (이미 있으면 아무것도 하지 않는다).
--   2. wind_totem 의 push_range_y 를 3 에서 1 로 내린다.
--   3. wind_totem 에 push_range_z = 3 을 새로 넣는다.
--
-- 높이를 1 로 두는 이유: 지상 mob 은 y=0 이고, 공중 mob 은 ZPhysics 가 AERIAL_MOB_INIT_HEIGHT(3)
-- 에 띄운다. TargetMask 는 y >= AERIAL_STANDARD_HEIGHT(2) 를 공중으로 본다. 0 과 2 사이에 머무는
-- mob 이 없으므로 1 이든 2 든 동작은 같고, 1 이 "지면에 붙은 것만 민다"는 뜻을 분명히 한다. 이
-- 값을 2 이상으로 올리면 바람 토템이 공중 mob 도 밀기 시작한다.
--
-- 배포 순서: game server 는 parameter 행이 없으면 getValue 에서 throw 하고 그 경기가 끝난다.
-- 이 migration 이 적용된 뒤에 push_range_z 를 읽는 game server(ArcaneCastersGame#41)가
-- 배포돼야 한다.
--
-- magics.indicator 는 건드리지 않는다. wind_totem 의 lane layer 는 halfWidth 리터럴 1.5 를
-- 쓰는데, 다른 lane 들은 halfWidth 에 radius(반지름)를 참조한다. push_range_z 는 전체 깊이 3
-- 이라 그대로 참조하면 2배가 된다. indicator 정리는 이 migration 범위 밖이다.
--
-- push_range_x, push_range_y, push_range_z 는 parameters.name 과 game_objects.name 을 거쳐
-- parameter_values 에 붙어 있고, game server 가 그 이름으로 읽는다. id 값에 의존하지 않도록
-- 이름으로 join 한다.
--
-- no-tags: game_objects 와 magics 에 새 행을 넣지 않는다. parameters 와 parameter_values 만
-- 바꾼다.

-- push_range_x 와 push_range_y 행이 실제로 있는지 먼저 확인한다. 이름이 어긋나면 조용히 옛
-- 값으로 남는 것이 이 저장소가 막으려는 실패다.
DO
$$
    DECLARE
        missing text;
    BEGIN
        SELECT string_agg(expected.name, ', ' ORDER BY expected.name)
        INTO missing
        FROM (VALUES ('push_range_x'), ('push_range_y')) AS expected(name)
        WHERE NOT EXISTS (SELECT 1
                          FROM game_objects object
                                   JOIN parameter_values stored ON stored.game_object_id = object.id
                                   JOIN parameters parameter ON parameter.id = stored.parameter_id
                          WHERE object.name = 'wind_totem'
                            AND parameter.name = expected.name);

        IF missing IS NOT NULL THEN
            RAISE EXCEPTION 'wind_totem is missing a parameter_values row for: %', missing;
        END IF;
    END
$$;

-- push_range_z 를 이름으로 등록한다. id 는 지정하지 않는다.
INSERT INTO parameters(name)
VALUES ('push_range_z')
ON CONFLICT (name) DO NOTHING;

-- 값이 이미 같으면 아무것도 바꾸지 않는다. 그래서 다시 돌려도 updated_at 이 또 올라가지 않는다
-- (migration rule 3).
UPDATE parameter_values stored
SET value      = 1,
    updated_at = now()
FROM game_objects object,
     parameters parameter
WHERE stored.game_object_id = object.id
  AND stored.parameter_id = parameter.id
  AND object.name = 'wind_totem'
  AND parameter.name = 'push_range_y'
  AND stored.value IS DISTINCT FROM 1;

-- push_range_z 행이 없으면 넣고, 있는데 값이 다르면 3 으로 맞춘다.
INSERT INTO parameter_values(parameter_id, game_object_id, value)
SELECT parameter.id, object.id, 3
FROM game_objects object,
     parameters parameter
WHERE object.name = 'wind_totem'
  AND parameter.name = 'push_range_z'
ON CONFLICT (parameter_id, game_object_id) DO UPDATE
    SET value      = EXCLUDED.value,
        updated_at = now()
    WHERE parameter_values.value IS DISTINCT FROM EXCLUDED.value;

-- 끝난 뒤 wind_totem 의 세 값이 6, 1, 3 인지 확인한다.
DO
$$
    DECLARE
        actual_x double precision;
        actual_y double precision;
        actual_z double precision;
    BEGIN
        SELECT stored.value
        INTO actual_x
        FROM game_objects object
                 JOIN parameter_values stored ON stored.game_object_id = object.id
                 JOIN parameters parameter ON parameter.id = stored.parameter_id
        WHERE object.name = 'wind_totem'
          AND parameter.name = 'push_range_x';

        SELECT stored.value
        INTO actual_y
        FROM game_objects object
                 JOIN parameter_values stored ON stored.game_object_id = object.id
                 JOIN parameters parameter ON parameter.id = stored.parameter_id
        WHERE object.name = 'wind_totem'
          AND parameter.name = 'push_range_y';

        SELECT stored.value
        INTO actual_z
        FROM game_objects object
                 JOIN parameter_values stored ON stored.game_object_id = object.id
                 JOIN parameters parameter ON parameter.id = stored.parameter_id
        WHERE object.name = 'wind_totem'
          AND parameter.name = 'push_range_z';

        IF actual_x IS DISTINCT FROM 6 OR actual_y IS DISTINCT FROM 1 OR actual_z IS DISTINCT FROM 3 THEN
            RAISE EXCEPTION 'wind_totem push_range not applied: x=% (expected 6) y=% (expected 1) z=% (expected 3)',
                actual_x, actual_y, actual_z;
        END IF;

        RAISE NOTICE 'wind_totem now carries push_range_x=6, push_range_y=1, push_range_z=3';
    END
$$;

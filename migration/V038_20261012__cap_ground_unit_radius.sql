-- 강 맵의 다리 폭은 3 이다. 지름이 3 이상인 지상 유닛은 다리를 건너지 못하거나, 조금만 밀려도
-- water 칸 가장자리의 EdgeCollider 에 걸린다. 지상 유닛 radius 상한을 1.2 로 정하고, 그보다 큰
-- 4종을 1.2 로 줄인다. 1.2 는 evil_ent 와 sea_serpent 가 이미 쓰는 값이라 양쪽에 0.3 씩 여유가 남는다.
--
--   wall_golem    1.8 -> 1.2
--   rock_golem    1.5 -> 1.2
--   tree_golem    1.5 -> 1.2
--   magma_spirit  1.5 -> 1.2
--
-- 1.2 보다 큰 값만 1.2 로 내린다. 이미 1.2 이하인 행은 건드리지 않으므로 다시 돌려도 updated_at 이
-- 또 올라가지 않는다 (migration rule 3).
--
-- radius 행이 없으면 Parameters.getValue 가 예외를 던져 경기가 그 자리에서 끝나므로, 이 파일은
-- update 만 하고 행이 없으면 먼저 막는다.
--
-- no-tags: magics 와 game_objects 에 새 행을 넣지 않는다. 기존 행의 값만 바꾼다.

DO
$$
    DECLARE
        missing text;
    BEGIN
        SELECT string_agg(expected.name, ', ')
        INTO missing
        FROM (VALUES ('wall_golem'), ('rock_golem'), ('tree_golem'), ('magma_spirit')) AS expected(name)
        WHERE NOT EXISTS (SELECT 1
                          FROM game_objects object
                                   JOIN parameter_values stored ON stored.game_object_id = object.id
                                   JOIN parameters parameter ON parameter.id = stored.parameter_id
                              AND parameter.name = 'radius'
                          WHERE object.name = expected.name);
        IF missing IS NOT NULL THEN
            RAISE EXCEPTION 'radius row missing for: %', missing;
        END IF;
    END
$$;

-- 네 magic 의 소환 indicator 는 같은 이름 object 의 radius 를 원으로 그린다. lobby 의 MagicDataService 는
-- magic 목록의 version 을 max(magics.updated_at) 으로 만들기 때문에, 값을 바꾼 object 와 이름이 같은
-- magics 행의 updated_at 도 올린다. 안 올리면 목록을 받아 둔 client 가 옛 원 크기를 계속 그린다.
WITH changed AS (
    UPDATE parameter_values stored
        SET value = 1.2,
            updated_at = now()
        FROM game_objects object,
            parameters parameter
        WHERE object.name IN ('wall_golem', 'rock_golem', 'tree_golem', 'magma_spirit')
            AND parameter.name = 'radius'
            AND stored.game_object_id = object.id
            AND stored.parameter_id = parameter.id
            AND stored.value > 1.2
        RETURNING object.name)
UPDATE magics
SET updated_at = now()
WHERE name IN (SELECT name FROM changed);

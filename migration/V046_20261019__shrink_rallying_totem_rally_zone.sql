-- rallying_totem 의 집결 구역 반경 effect_radius 를 3 에서 2 로 줄인다.
--
-- effect_radius 는 V039 부터 세 곳에 쓰인다: 모인 mob 이 멈춰 서는 집결 구역, 공격 대상을 토템에서
-- 이 거리 안의 적으로 제한하는 반경, 공격속도 buff(Inspired) 반경. magics.indicator 도 이 값을
-- 읽으므로 시전 표시의 안쪽 원도 함께 줄어든다.
--
--   effect_radius    3 -> 2
--
-- detection_range (8, 모집 반경) 와 나머지 값은 그대로 둔다.
--
-- 값이 이미 2 이면 update 하지 않아 다시 돌려도 updated_at 이 오르지 않는다 (migration rule 3).
--
-- no-tags: magics 와 game_objects 에 새 행을 넣지 않는다. 기존 행의 값만 바꾼다.

DO
$$
    BEGIN
        IF NOT EXISTS (SELECT 1
                       FROM parameter_values stored
                                JOIN game_objects object ON object.id = stored.game_object_id
                                JOIN parameters parameter ON parameter.id = stored.parameter_id
                       WHERE object.name = 'rallying_totem'
                         AND parameter.name = 'effect_radius') THEN
            RAISE EXCEPTION 'parameter_values row missing for rallying_totem.effect_radius';
        END IF;
    END
$$;

UPDATE parameter_values stored
SET value      = 2.0,
    updated_at = now()
FROM game_objects object,
     parameters parameter
WHERE object.name = 'rallying_totem'
  AND parameter.name = 'effect_radius'
  AND stored.game_object_id = object.id
  AND stored.parameter_id = parameter.id
  AND stored.value IS DISTINCT FROM 2.0;

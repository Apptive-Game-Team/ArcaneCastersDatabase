-- rallying_totem 을 하늘에서 떨어지는 Drop 으로 바꾸고, 집결 구역과 모집 반경 값을 정한다.
--
-- 옛 동작: Summon 이라 그 자리에 바로 생기고, 아군 mob 이 Item 으로 집어 옮길 수 있었다. 맵 전체의
-- 아군 mob 을 totem 중심 한 점으로 끌어당겼고, 전투 leash 는 `range` 를 읽었다. magic-card 개편 뒤
-- `range` 는 옛 반경 2 가 아니라 시전 사거리 6 이라서 (V001 baseline 85 행 근처 주석), leash 가 3배로
-- 늘어나 있었다.
-- 새 동작: 낙하해 자리를 잡고 옮길 수 없다. `detection_range` 안의 아군 mob 만 모으고, mob 은
-- `effect_radius` 안에 들어서면 멈춰 그 자리에서 공격한다.
--
--   magics.cast_kind               Summon -> Drop (frenzy_totem 과 같다)
--   speed            (신규)        5   낙하 속도. frenzy_totem 의 speed 와 같다
--   effect_radius    2 -> 3        집결 구역 반경이자 공격속도 buff 반경
--   detection_range  (신규)        8   mob 을 모집하는 반경
--   magics.indicator               effect_radius 원 + detection_range 원 (healing_totem 과 같은 두 겹)
--
-- radius (0.6, collider), range (6, 시전 사거리), duration, buff_duration, mana_cost 는 그대로 둔다.
--
-- parameter_values 에는 (game_object_id, parameter_id) 유일 제약이 없어서 ON CONFLICT 를 쓰지 못한다.
-- 그래서 update 한 뒤 행이 없을 때만 insert 한다. 값이 이미 같으면 update 하지 않아 다시 돌려도
-- updated_at 이 오르지 않는다 (migration rule 3).
--
-- no-tags: magics 와 game_objects 에 새 행을 넣지 않는다. 기존 행의 값만 바꾼다.

DO
$$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM game_objects WHERE name = 'rallying_totem') THEN
            RAISE EXCEPTION 'game_objects row missing for rallying_totem';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM magics WHERE name = 'rallying_totem') THEN
            RAISE EXCEPTION 'magics row missing for rallying_totem';
        END IF;
        IF (SELECT count(*) FROM parameters WHERE name IN ('speed', 'effect_radius', 'detection_range')) <> 3 THEN
            RAISE EXCEPTION 'parameters row missing for speed, effect_radius or detection_range';
        END IF;
    END
$$;

WITH wanted(parameter_name, value) AS (VALUES ('speed', 5.0::double precision),
                                              ('effect_radius', 3.0::double precision),
                                              ('detection_range', 8.0::double precision))
UPDATE parameter_values stored
SET value      = wanted.value,
    updated_at = now()
FROM wanted,
     game_objects object,
     parameters parameter
WHERE object.name = 'rallying_totem'
  AND parameter.name = wanted.parameter_name
  AND stored.game_object_id = object.id
  AND stored.parameter_id = parameter.id
  AND stored.value IS DISTINCT FROM wanted.value;

WITH wanted(parameter_name, value) AS (VALUES ('speed', 5.0::double precision),
                                              ('effect_radius', 3.0::double precision),
                                              ('detection_range', 8.0::double precision))
INSERT
INTO parameter_values(parameter_id, game_object_id, value)
SELECT parameter.id, object.id, wanted.value
FROM wanted
         JOIN parameters parameter ON parameter.name = wanted.parameter_name
         JOIN game_objects object ON object.name = 'rallying_totem'
WHERE NOT EXISTS (SELECT 1
                  FROM parameter_values stored
                  WHERE stored.game_object_id = object.id
                    AND stored.parameter_id = parameter.id);

UPDATE magics
SET cast_kind  = 'Drop',
    indicator  = '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "rallying_totem", "parameter": "effect_radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "rallying_totem", "parameter": "detection_range"}, "edgeWidth": 0.08}], "version": 1}'::jsonb,
    updated_at = now()
WHERE name = 'rallying_totem'
  AND (cast_kind IS DISTINCT FROM 'Drop'
    OR indicator IS DISTINCT FROM
       '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "rallying_totem", "parameter": "effect_radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "rallying_totem", "parameter": "detection_range"}, "edgeWidth": 0.08}], "version": 1}'::jsonb);

DO
$$
    DECLARE
        wrong text;
    BEGIN
        SELECT string_agg(wanted.parameter_name, ', ')
        INTO wrong
        FROM (VALUES ('speed', 5.0), ('effect_radius', 3.0), ('detection_range', 8.0)) AS wanted(parameter_name, value)
        WHERE (SELECT count(*)
               FROM parameter_values stored
                        JOIN game_objects object ON object.id = stored.game_object_id AND object.name = 'rallying_totem'
                        JOIN parameters parameter ON parameter.id = stored.parameter_id AND parameter.name = wanted.parameter_name
               WHERE stored.value = wanted.value) <> 1;
        IF wrong IS NOT NULL THEN
            RAISE EXCEPTION 'rallying_totem parameter_values not exactly one row of the wanted value: %', wrong;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM magics WHERE name = 'rallying_totem' AND cast_kind = 'Drop') THEN
            RAISE EXCEPTION 'rallying_totem cast_kind is not Drop';
        END IF;
    END
$$;

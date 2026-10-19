-- 분화구 운반수의 공격 주기와 설치/회수 시간을 늘리고 체력을 낮춘다.
--
--   attack_interval    2.6 -> 4.0
--   setup_duration     1.2 -> 2.0
--   recovery_duration  0.9 -> 1.5
--   hp                 440 -> 300
--
-- 값이 이미 목표값이면 update 하지 않아 다시 실행해도 updated_at 이 오르지 않는다.
--
-- no-tags: magics 와 game_objects 에 새 행을 넣지 않는다. 기존 밸런스 값만 바꾼다.

DO
$$
    DECLARE
        missing_parameter text;
    BEGIN
        SELECT expected.parameter_name
        INTO missing_parameter
        FROM (VALUES ('attack_interval'),
                     ('setup_duration'),
                     ('recovery_duration'),
                     ('hp')) AS expected(parameter_name)
        WHERE NOT EXISTS (SELECT 1
                          FROM parameter_values stored
                                   JOIN game_objects object ON object.id = stored.game_object_id
                                   JOIN parameters parameter ON parameter.id = stored.parameter_id
                          WHERE object.name = 'crater_carrier'
                            AND parameter.name = expected.parameter_name)
        LIMIT 1;

        IF missing_parameter IS NOT NULL THEN
            RAISE EXCEPTION 'parameter_values row missing for crater_carrier.%', missing_parameter;
        END IF;
    END
$$;

UPDATE parameter_values stored
SET value      = desired.value,
    updated_at = now()
FROM game_objects object,
     parameters parameter,
     (VALUES ('attack_interval', 4.0::double precision),
             ('setup_duration', 2.0::double precision),
             ('recovery_duration', 1.5::double precision),
             ('hp', 300.0::double precision)) AS desired(parameter_name, value)
WHERE object.name = 'crater_carrier'
  AND parameter.name = desired.parameter_name
  AND stored.game_object_id = object.id
  AND stored.parameter_id = parameter.id
  AND stored.value IS DISTINCT FROM desired.value;

DO
$$
    DECLARE
        incorrect_parameter text;
    BEGIN
        SELECT desired.parameter_name
        INTO incorrect_parameter
        FROM (VALUES ('attack_interval', 4.0::double precision),
                     ('setup_duration', 2.0::double precision),
                     ('recovery_duration', 1.5::double precision),
                     ('hp', 300.0::double precision)) AS desired(parameter_name, value)
        WHERE NOT EXISTS (SELECT 1
                          FROM parameter_values stored
                                   JOIN game_objects object ON object.id = stored.game_object_id
                                   JOIN parameters parameter ON parameter.id = stored.parameter_id
                          WHERE object.name = 'crater_carrier'
                            AND parameter.name = desired.parameter_name
                            AND stored.value = desired.value)
        LIMIT 1;

        IF incorrect_parameter IS NOT NULL THEN
            RAISE EXCEPTION 'parameter value incorrect for crater_carrier.%', incorrect_parameter;
        END IF;
    END
$$;

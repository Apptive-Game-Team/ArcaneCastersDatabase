-- 돌무더기 하나의 피해 반경을 조정한다. 조준점에서 돌무더기를 고르는 반경은 rock_blast.radius에 있다.
UPDATE parameter_values stored
SET value = 1.5,
    updated_at = now()
FROM game_objects object, parameters parameter
WHERE object.name = 'rock_explode'
  AND parameter.name = 'radius'
  AND stored.game_object_id = object.id
  AND stored.parameter_id = parameter.id
  AND stored.value IS DISTINCT FROM 1.5;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM parameter_values stored
        JOIN game_objects object ON object.id = stored.game_object_id
        JOIN parameters parameter ON parameter.id = stored.parameter_id
        WHERE object.name = 'rock_explode'
          AND parameter.name = 'radius'
          AND stored.value = 1.5
    ) THEN
        RAISE EXCEPTION 'rock_explode.radius is missing or was not set to 1.5';
    END IF;
END
$$;

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
DECLARE
    blast_layer constant jsonb := '{
        "shape": "objectCircles",
        "origin": "target",
        "prefabs": ["RockRemnant", "MediumRockRemnant"],
        "selectionRadius": {"object": "rock_blast", "parameter": "radius"},
        "radius": {"object": "rock_explode", "parameter": "radius"},
        "edgeWidth": 0.12
    }'::jsonb;
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

    UPDATE magics
    SET indicator = jsonb_set(indicator, '{layers}', (indicator -> 'layers') || jsonb_build_array(blast_layer)),
        updated_at = now()
    WHERE name = 'rock_blast'
      AND indicator ->> 'version' = '1'
      AND jsonb_typeof(indicator -> 'layers') = 'array'
      AND NOT ((indicator -> 'layers') @> jsonb_build_array(blast_layer));

    IF NOT EXISTS (
        SELECT 1 FROM magics
        WHERE name = 'rock_blast'
          AND indicator ->> 'version' = '1'
          AND (indicator -> 'layers') @> jsonb_build_array(blast_layer)
    ) THEN
        RAISE EXCEPTION 'rock_blast indicator is missing its objectCircles layer';
    END IF;
END
$$;

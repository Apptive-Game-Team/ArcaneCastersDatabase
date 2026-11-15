-- 작은 돌무더기의 피해 반경을 조정한다. 돌무더기를 고르는 반경은 rock_blast.radius에 있다.
UPDATE parameter_values stored
SET value = 1.5,
    updated_at = now()
FROM game_objects object, parameters parameter
WHERE object.name = 'rock_explode'
  AND parameter.name = 'radius'
  AND stored.game_object_id = object.id
  AND stored.parameter_id = parameter.id
  AND stored.value IS DISTINCT FROM 1.5;

INSERT INTO parameters(name)
VALUES ('medium_blast_radius')
ON CONFLICT (name) DO NOTHING;

INSERT INTO parameter_values AS stored (game_object_id, parameter_id, value)
SELECT object.id, parameter.id, 2.0
FROM game_objects object, parameters parameter
WHERE object.name = 'rock_explode'
  AND parameter.name = 'medium_blast_radius'
ON CONFLICT (parameter_id, game_object_id) DO UPDATE
SET value = EXCLUDED.value, updated_at = now()
WHERE stored.value IS DISTINCT FROM EXCLUDED.value;

DO $$
DECLARE
    blast_layers constant jsonb := '[{
        "shape": "objectCircles",
        "origin": "target",
        "prefabs": ["RockRemnant"],
        "selectionRadius": {"object": "rock_blast", "parameter": "radius"},
        "radius": {"object": "rock_explode", "parameter": "radius"},
        "edgeWidth": 0.12
    }, {
        "shape": "objectCircles",
        "origin": "target",
        "prefabs": ["MediumRockRemnant"],
        "selectionRadius": {"object": "rock_blast", "parameter": "radius"},
        "radius": {"object": "rock_explode", "parameter": "medium_blast_radius"},
        "edgeWidth": 0.12
    }]'::jsonb;
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
    SET indicator = jsonb_set(indicator, '{layers}', (indicator -> 'layers') || blast_layers),
        updated_at = now()
    WHERE name = 'rock_blast'
      AND indicator ->> 'version' = '1'
      AND jsonb_typeof(indicator -> 'layers') = 'array'
      AND NOT ((indicator -> 'layers') @> blast_layers);

    IF NOT EXISTS (
        SELECT 1 FROM magics
        WHERE name = 'rock_blast'
          AND indicator ->> 'version' = '1'
          AND (indicator -> 'layers') @> blast_layers
    ) THEN
        RAISE EXCEPTION 'rock_blast indicator is missing its objectCircles layer';
    END IF;
END
$$;

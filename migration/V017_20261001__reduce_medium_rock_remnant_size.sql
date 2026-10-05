UPDATE parameter_values
SET value = 0.75,
    updated_at = CURRENT_TIMESTAMP
WHERE game_object_id = (
        SELECT id
        FROM game_objects
        WHERE name = 'medium_rock_remnant'
    )
  AND parameter_id = (
        SELECT id
        FROM parameters
        WHERE name = 'radius'
    )
  AND value = 1.0;

DO $$
DECLARE
    actual_radius DOUBLE PRECISION;
BEGIN
    SELECT pv.value
    INTO actual_radius
    FROM parameter_values pv
    JOIN game_objects go ON go.id = pv.game_object_id
    JOIN parameters p ON p.id = pv.parameter_id
    WHERE go.name = 'medium_rock_remnant'
      AND p.name = 'radius';

    IF actual_radius IS DISTINCT FROM 0.75 THEN
        RAISE EXCEPTION
            'medium_rock_remnant.radius must be 0.75, got %',
            actual_radius;
    END IF;
END
$$;

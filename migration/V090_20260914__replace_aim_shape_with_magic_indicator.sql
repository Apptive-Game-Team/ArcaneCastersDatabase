-- magic-card: aim_shape was one number (1 = straight line, 0 = circle), seeded in V084 from
-- magics.cast_type. It cannot describe a shape with a radius, an offset, or more than one
-- layer, so it is replaced with a jsonb document that the client draws directly.
--
-- Document contract (version 1), fixed by the client that reads it and not to be changed here:
--
--   {"version": 1, "layers": [<layer>, ...]}
--
-- Both layer shapes this migration writes reference the magic's own parameters rather than
-- inlining numbers, so a later balance change to radius/attack_range/attack_offset keeps
-- matching the drawn indicator without touching this table again.

-- ---------------------------------------------------------------------------- the column
ALTER TABLE magics
    ADD COLUMN IF NOT EXISTS indicator jsonb;

-- --------------------------------------------------------------------------- the backfill
--
-- A magic's own parameters are found the way every other magic-card migration finds them:
-- magics.name = game_objects.name, then parameter_values joined to parameters by name. See
-- V084 for why that join exists (game_objects rows created there for magics with no other
-- game object) and V089 for magics that carry attack_range on that same row.
--
-- base_layer reproduces today's on-screen behaviour exactly:
--   aim_shape = 1                       -> a lane from the caster to the aim point, half width
--                                          the magic's own radius parameter.
--   aim_shape = 0, or no aim_shape row  -> a filled circle at the aim point, radius the magic's
--                                          own radius parameter.
--
-- attack_layer is additional: a magic whose own row also carries attack_range gets a second,
-- ring-only layer showing where the built object will actually strike. No magic in this
-- repository's migration chain carries an attack_offset parameter today, so forwardOffset
-- falls back to 0 until one does; the layer is still written unconditionally on attack_range
-- so it is already correct when such a magic arrives.
-- The join to game_objects is a LEFT JOIN on purpose. V084 inserts a game_objects row for
-- every magic, so it should always hit, but about 50 magics exist only in the operational
-- database and cannot be checked here. With an inner join a single missing row would produce
-- no layer for that magic, and the SET NOT NULL two statements below would abort the whole
-- migration. With a LEFT JOIN that magic falls through to the base circle instead, which is
-- what a magic with no parameters of its own should draw anyway.
WITH magic_object AS (SELECT magic.id        AS magic_id,
                             game_object.id AS game_object_id
                      FROM magics magic
                               LEFT JOIN game_objects game_object ON game_object.name = magic.name),
     layer_row AS (SELECT magic_object.magic_id,
                          1 AS layer_order,
                          CASE
                              WHEN aim_shape.value = 1 THEN
                                  jsonb_build_object('shape', 'lane',
                                                      'origin', 'caster',
                                                      'end', 'target',
                                                      'halfWidth', jsonb_build_object('parameter', 'radius'))
                              ELSE
                                  jsonb_build_object('shape', 'circle',
                                                      'origin', 'target',
                                                      'radius', jsonb_build_object('parameter', 'radius'))
                              END AS layer
                   FROM magic_object
                            LEFT JOIN parameters aim_shape_parameter ON aim_shape_parameter.name = 'aim_shape'
                            LEFT JOIN parameter_values aim_shape
                                      ON aim_shape.game_object_id = magic_object.game_object_id
                                          AND aim_shape.parameter_id = aim_shape_parameter.id
                   UNION ALL
                   SELECT magic_object.magic_id,
                          2 AS layer_order,
                          jsonb_build_object('shape', 'circle',
                                              'origin', 'target',
                                              'forwardOffset',
                                              jsonb_build_object('parameter', 'attack_offset', 'fallback', 0),
                                              'radius', jsonb_build_object('parameter', 'attack_range'),
                                              'edgeWidth', 0.08) AS layer
                   FROM magic_object
                            JOIN parameters attack_range_parameter ON attack_range_parameter.name = 'attack_range'
                            JOIN parameter_values attack_range
                                 ON attack_range.game_object_id = magic_object.game_object_id
                                     AND attack_range.parameter_id = attack_range_parameter.id
                                     AND attack_range.value IS NOT NULL),
     magic_indicator AS (SELECT magic_id,
                                jsonb_agg(layer ORDER BY layer_order) AS layers
                         FROM layer_row
                         GROUP BY magic_id)
UPDATE magics
SET indicator = jsonb_build_object('version', 1, 'layers', magic_indicator.layers)
FROM magic_indicator
WHERE magic_indicator.magic_id = magics.id
  AND magics.indicator IS NULL;

-- The default matters as much as the NOT NULL. Registration migrations arrive constantly on the
-- other chain (V077 through V082 registered six magics, V089 five more) and none of them names a
-- column this migration had not added yet. Without a default the next INSERT INTO magics fails
-- with "null value in column indicator violates not-null constraint" and the dev database stops
-- migrating. A base circle at the aim point sized by the magic's own radius parameter is what a
-- newly registered magic should draw anyway, and it is exactly what the client falls back to when
-- a document is missing, so the default and the fallback agree. A magic that needs a lane or a
-- strike layer sets indicator explicitly in its own registration migration.
ALTER TABLE magics
    ALTER COLUMN indicator SET DEFAULT
        '{"version": 1, "layers": [{"shape": "circle", "origin": "target", "radius": {"parameter": "radius"}}]}'::jsonb;

ALTER TABLE magics
    ALTER COLUMN indicator SET NOT NULL;

-- -------------------------------------------------------------------------- remove aim_shape
--
-- The jsonb document is now the single source of the indicator shape. aim_shape is read
-- nowhere else in this repository (V084 seeded it, V085's comment only notes that V084 already
-- consumed cast_type into it, V089 seeded it for the five composite magics) so both the values
-- and the parameter definition can go.
DELETE
FROM parameter_values
WHERE parameter_id = (SELECT id FROM parameters WHERE name = 'aim_shape');

DELETE
FROM parameters
WHERE name = 'aim_shape';

-- --------------------------------------------------------------------------- assertions
DO
$$
    DECLARE
        magic_count        INTEGER;
        uncovered_names    TEXT;
        malformed_names    TEXT;
        lane_count         INTEGER;
        circle_count       INTEGER;
        attack_layer_count INTEGER;
        aim_shape_survives INTEGER;
    BEGIN
        SELECT COUNT(*) INTO magic_count FROM magics;

        SELECT COALESCE(STRING_AGG(magic.name, ', ' ORDER BY magic.name), '')
        INTO uncovered_names
        FROM magics magic
        WHERE magic.indicator IS NULL
           OR magic.indicator -> 'layers' IS NULL
           OR jsonb_array_length(magic.indicator -> 'layers') = 0;

        IF uncovered_names <> '' THEN
            RAISE EXCEPTION 'these magics have a null or empty indicator: %', uncovered_names;
        END IF;

        SELECT COALESCE(STRING_AGG(magic.name, ', ' ORDER BY magic.name), '')
        INTO malformed_names
        FROM magics magic
        WHERE (magic.indicator ->> 'version') IS DISTINCT FROM '1'
           OR jsonb_typeof(magic.indicator -> 'layers') IS DISTINCT FROM 'array';

        IF malformed_names <> '' THEN
            RAISE EXCEPTION 'these magics do not carry version 1 with a layers array: %', malformed_names;
        END IF;

        SELECT COUNT(*) FILTER (WHERE layer ->> 'shape' = 'lane'),
               COUNT(*) FILTER (WHERE layer ->> 'shape' = 'circle' AND layer ->> 'origin' = 'target' AND
                                      layer -> 'edgeWidth' IS NULL),
               COUNT(*) FILTER (WHERE layer -> 'edgeWidth' IS NOT NULL)
        INTO lane_count, circle_count, attack_layer_count
        FROM magics magic,
             jsonb_array_elements(magic.indicator -> 'layers') AS layer;

        SELECT COUNT(*) INTO aim_shape_survives FROM parameters WHERE name = 'aim_shape';

        IF aim_shape_survives > 0 THEN
            RAISE EXCEPTION 'aim_shape parameter still exists after this migration should have removed it';
        END IF;

        RAISE NOTICE '% magics carry a non-empty version-1 indicator', magic_count;
        RAISE NOTICE '% magics backfilled with a lane (former aim_shape 1)', lane_count;
        RAISE NOTICE '% magics backfilled with a base circle (former aim_shape 0 or missing)', circle_count;
        RAISE NOTICE '% magics additionally carry an attack_range strike layer', attack_layer_count;
        RAISE NOTICE 'aim_shape parameter and its values removed';
    END
$$;

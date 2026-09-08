-- no-tags: every game_objects row inserted here is a parameter key for a magic that already
-- exists. Nothing new reaches the field, and the magics involved already carry magic_tags
-- through magic_game_object_aliases, which sync_magic_tags_from_game_objects() consults
-- ahead of the name join. See the "parameter keys" section below.
--
-- magic-card: mana cost, cast range and aim shape move from the cast-type card to the magic.
--
-- Today the game server reads both from the cast type:
--
--   PlayerData.validCardsUse   sum over the played cards of
--                              parameters.getValue(lower(card name), "mana_cost")
--   MagicInputHandler          parameters.getValue(magic.magicType.name(), "range")
--
-- ParameterRepository lowercases the game object name before the lookup, so those keys are
-- the game_objects rows named fire, water, lightning, rock, nature, wind, shoot, build,
-- spawn, explode and drop. After the redesign there are no cast-type cards left to key on,
-- so the key becomes the magic's own name and game_objects.name = magics.name.
--
-- Initial values reproduce today's numbers exactly, computed in SQL rather than listed:
-- only 19 of the ~69 recipes exist in this repository and the rest are in the live database
-- only.
--
--   mana_cost   sum of the mana_cost of every card in the recipe, duplicates counted
--   range       the range of the game object named by magics.cast_type
--   aim_shape   1 when magics.cast_type is 'shoot', otherwise 0
--
-- range and aim_shape are taken from magics.cast_type rather than from the recipe's cast-type
-- card, and the two are not always the same thing. magic.magicType comes from the Java class
-- the magic extends (AbstractSpawnMagic passes CardType.Spawn), V047 wrote magics.cast_type
-- to match it, and two recipes hold a second cast-type card: cloud_dragon gained a Shoot card
-- in V072 and sea_serpent was registered with Shoot + Spawn in V070. Both cast as Spawn today
-- and both draw a circular aim marker today. Reading the recipe instead would give them a
-- Shoot range of 18 and a straight aim line, which is a balance change, and this migration is
-- supposed to change nothing. The two are listed in a NOTICE at the end.
--
-- The old keys are left alone. fire, shoot and the other nine cast-type objects keep their
-- mana_cost and range, so the running game server keeps working after this migration and
-- before the server change lands.

-- --------------------------------------------------------------------------- parameters
--
-- aim_shape is new. effect_radius already exists (bubble_generator uses it for its aura) and
-- is claimed below for the objects whose range means something other than a cast range.
INSERT INTO parameters(name)
SELECT required.name
FROM (VALUES ('mana_cost'),
             ('range'),
             ('aim_shape'),
             ('effect_radius')) AS required(name)
WHERE NOT EXISTS (SELECT 1 FROM parameters existing WHERE existing.name = required.name);

-- Every card must resolve to a game object carrying mana_cost, or its contribution to the sum
-- below would silently be zero: the LEFT JOINs that keep one row per magic also swallow a
-- missing card. Assert it here rather than discovering a free magic in a match.
DO
$$
    DECLARE
        unpriced_cards TEXT;
    BEGIN
        SELECT STRING_AGG(card.name, ', ' ORDER BY card.name)
        INTO unpriced_cards
        FROM cards card
        WHERE NOT EXISTS (SELECT 1
                          FROM parameter_values card_mana_cost
                                   JOIN game_objects card_object
                                        ON card_object.id = card_mana_cost.game_object_id
                                   JOIN parameters mana_cost_parameter
                                        ON mana_cost_parameter.id = card_mana_cost.parameter_id
                          WHERE card_object.name = LOWER(card.name)
                            AND mana_cost_parameter.name = 'mana_cost'
                            AND card_mana_cost.value IS NOT NULL);

        IF unpriced_cards IS NOT NULL THEN
            RAISE EXCEPTION 'these cards have no mana_cost parameter and would count as free: %', unpriced_cards;
        END IF;
    END
$$;

-- Every cast type must resolve to a game object carrying range, for the same reason.
DO
$$
    DECLARE
        unranged_cast_types TEXT;
    BEGIN
        SELECT STRING_AGG(DISTINCT magic.cast_type, ', ')
        INTO unranged_cast_types
        FROM magics magic
        WHERE NOT EXISTS (SELECT 1
                          FROM parameter_values cast_range
                                   JOIN game_objects cast_object
                                        ON cast_object.id = cast_range.game_object_id
                                   JOIN parameters range_parameter
                                        ON range_parameter.id = cast_range.parameter_id
                          WHERE cast_object.name = magic.cast_type
                            AND range_parameter.name = 'range'
                            AND cast_range.value IS NOT NULL);

        IF unranged_cast_types IS NOT NULL THEN
            RAISE EXCEPTION 'these cast types have no range parameter: %', unranged_cast_types;
        END IF;
    END
$$;

-- ------------------------------------------------------------------------ parameter keys
--
-- game_objects.name is varchar(31) and magics.name is varchar(255). Nothing is close to the
-- limit today, but a name that does not fit has no key at all and would fail the coverage
-- assertion at the end with a foreign key error instead of a readable message.
DO
$$
    DECLARE
        overlong_magic_names TEXT;
    BEGIN
        SELECT STRING_AGG(magic.name, ', ' ORDER BY magic.name)
        INTO overlong_magic_names
        FROM magics magic
        WHERE LENGTH(magic.name) > 31;

        IF overlong_magic_names IS NOT NULL THEN
            RAISE EXCEPTION 'these magic names do not fit game_objects.name varchar(31): %', overlong_magic_names;
        END IF;
    END
$$;

-- Most magics are named after the object they create and already have this row. The ones that
-- are not -- the _swarm magics, cannon, tower, vine_world and the rest of the V065 alias list
-- -- get an empty row here that exists only to hang parameters off.
--
-- That does not disturb bot counter scoring. sync_magic_tags_from_game_objects() resolves a
-- magic through magic_game_object_aliases first and only falls back to the name join, so
-- ember_spirit_swarm keeps following ember_spirit's tags even though a game object now shares
-- its name. V065 states that precedence explicitly.
INSERT INTO game_objects(name)
SELECT magic.name
FROM magics magic
WHERE NOT EXISTS (SELECT 1 FROM game_objects existing WHERE existing.name = magic.name);

-- ------------------------------------------------------- range that is not a cast range
--
-- Some magics share a name with a live field object that already stores a range meaning
-- something else. healing_totem and life_tree pass it to Totem as the heal radius, and
-- rallying_totem got range 2.0 in V038 as its buff radius. Overwriting those with the cast
-- range would change three magics' behaviour with no error anywhere, which is exactly what
-- this migration must not do.
--
-- The old value is copied to effect_radius before range is claimed, so the game server can
-- move those three initializers from ParameterKey.RANGE to ParameterKey.EFFECT_RADIUS and get
-- the same number back. Written only where effect_radius is absent, so a re-run never
-- overwrites a value someone has since tuned.
--
-- The collisions are materialised first because they stop being visible the moment range is
-- overwritten, and the live database can hold collisions this repository cannot see. The list
-- is reported in the NOTICE at the end.
CREATE TEMP TABLE magic_range_collision AS
SELECT magic_object.id     AS game_object_id,
       magic_object.name   AS game_object_name,
       existing_range.value AS previous_range,
       cast_range.value    AS cast_range
FROM magics magic
         JOIN game_objects magic_object ON magic_object.name = magic.name
         JOIN game_objects cast_object ON cast_object.name = magic.cast_type
         JOIN parameters range_parameter ON range_parameter.name = 'range'
         JOIN parameter_values existing_range
              ON existing_range.game_object_id = magic_object.id
                  AND existing_range.parameter_id = range_parameter.id
         JOIN parameter_values cast_range
              ON cast_range.game_object_id = cast_object.id
                  AND cast_range.parameter_id = range_parameter.id
WHERE existing_range.value IS DISTINCT FROM cast_range.value;

INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT collision.game_object_id, effect_radius_parameter.id, collision.previous_range
FROM magic_range_collision collision
         JOIN parameters effect_radius_parameter ON effect_radius_parameter.name = 'effect_radius'
WHERE NOT EXISTS (SELECT 1
                  FROM parameter_values kept
                  WHERE kept.game_object_id = collision.game_object_id
                    AND kept.parameter_id = effect_radius_parameter.id);

-- ------------------------------------------------------------------------- the three values
--
-- mana_cost is a LEFT JOIN chain so that a magic with no recipe still produces one row, with
-- SUM over an empty set coalesced to 0. Twelve magics are in that state: the dead V003
-- catalogue names and the ones implemented on the game server but never given a recipe. They
-- are unreachable today and stay unreachable until something gives them a recipe or a deck
-- entry, and they are reported in the NOTICE at the end.
WITH mana_cost_per_magic AS (SELECT magic.id                              AS magic_id,
                                    COALESCE(SUM(card_mana_cost.value), 0) AS value
                             FROM magics magic
                                      LEFT JOIN magic_cards magic_card ON magic_card.magic_id = magic.id
                                      LEFT JOIN cards card ON card.id = magic_card.card_id
                                      LEFT JOIN game_objects card_object
                                                ON card_object.name = LOWER(card.name)
                                      LEFT JOIN parameters mana_cost_parameter
                                                ON mana_cost_parameter.name = 'mana_cost'
                                      LEFT JOIN parameter_values card_mana_cost
                                                ON card_mana_cost.game_object_id = card_object.id
                                                    AND card_mana_cost.parameter_id = mana_cost_parameter.id
                             GROUP BY magic.id),
     magic_parameter_values AS (SELECT magic.name                                                  AS magic_name,
                                       'mana_cost'                                                 AS parameter_name,
                                       mana_cost_per_magic.value                                   AS value
                                FROM magics magic
                                         JOIN mana_cost_per_magic ON mana_cost_per_magic.magic_id = magic.id
                                UNION ALL
                                SELECT magic.name,
                                       'range',
                                       cast_range.value
                                FROM magics magic
                                         JOIN game_objects cast_object ON cast_object.name = magic.cast_type
                                         JOIN parameters range_parameter ON range_parameter.name = 'range'
                                         JOIN parameter_values cast_range
                                              ON cast_range.game_object_id = cast_object.id
                                                  AND cast_range.parameter_id = range_parameter.id
                                UNION ALL
                                SELECT magic.name,
                                       'aim_shape',
                                       CASE WHEN magic.cast_type = 'shoot' THEN 1 ELSE 0 END
                                FROM magics magic)
INSERT
INTO parameter_values(game_object_id, parameter_id, value)
SELECT magic_object.id, parameter.id, magic_parameter_values.value
FROM magic_parameter_values
         JOIN game_objects magic_object ON magic_object.name = magic_parameter_values.magic_name
         JOIN parameters parameter ON parameter.name = magic_parameter_values.parameter_name
ON CONFLICT (parameter_id, game_object_id)
    DO UPDATE SET value      = EXCLUDED.value,
                  updated_at = NOW();

DO
$$
    DECLARE
        magic_count             INTEGER;
        covered_count           INTEGER;
        missing_names           TEXT;
        recipeless_names        TEXT;
        diverging_names         TEXT;
        preserved_effect_radius TEXT;
        straight_aim_count      INTEGER;
    BEGIN
        SELECT COUNT(*) INTO magic_count FROM magics;

        -- The point of the whole file: all three values present for every magic. This is the
        -- only check that reaches the ~50 recipes that live in the operational database and
        -- not in this repository, because V000 opens with `create database` and the chain
        -- cannot be replayed from empty to test them here.
        SELECT COUNT(*) FILTER (WHERE magic_value_count.value_count = 3),
               COALESCE(STRING_AGG(magic_value_count.name, ', ' ORDER BY magic_value_count.name)
                        FILTER (WHERE magic_value_count.value_count < 3), '')
        INTO covered_count, missing_names
        FROM (SELECT magic.name,
                     (SELECT COUNT(*)
                      FROM parameter_values magic_value
                               JOIN game_objects magic_object
                                    ON magic_object.id = magic_value.game_object_id
                               JOIN parameters parameter ON parameter.id = magic_value.parameter_id
                      WHERE magic_object.name = magic.name
                        AND parameter.name IN ('mana_cost', 'range', 'aim_shape')
                        AND magic_value.value IS NOT NULL) AS value_count
              FROM magics magic) magic_value_count;

        IF covered_count <> magic_count THEN
            RAISE EXCEPTION '% of % magics carry all three values; missing on: %',
                covered_count, magic_count, missing_names;
        END IF;

        SELECT COALESCE(STRING_AGG(magic.name, ', ' ORDER BY magic.name), '(none)')
        INTO recipeless_names
        FROM magics magic
        WHERE NOT EXISTS (SELECT 1 FROM magic_cards magic_card WHERE magic_card.magic_id = magic.id);

        -- The two recipes that hold a cast-type card other than their cast_type. Recorded so
        -- the choice made at the top of this file can be rechecked against the live data.
        SELECT COALESCE(STRING_AGG(diverging.name, ', ' ORDER BY diverging.name), '(none)')
        INTO diverging_names
        FROM (SELECT DISTINCT magic.name
              FROM magics magic
                       JOIN magic_cards magic_card ON magic_card.magic_id = magic.id
                       JOIN cards card ON card.id = magic_card.card_id
              WHERE card.card_type = 'Magic'
                AND LOWER(card.name) <> magic.cast_type) diverging;

        SELECT COALESCE(STRING_AGG(FORMAT('%s %s->%s', collision.game_object_name,
                                          collision.previous_range, collision.cast_range),
                                   ', ' ORDER BY collision.game_object_name), '(none)')
        INTO preserved_effect_radius
        FROM magic_range_collision collision;

        SELECT COUNT(*) INTO straight_aim_count FROM magics WHERE cast_type = 'shoot';

        RAISE NOTICE '% magics carry mana_cost, range and aim_shape', magic_count;
        RAISE NOTICE '% magics aim in a straight line (aim_shape 1)', straight_aim_count;
        RAISE NOTICE 'magics with no recipe, priced at 0 mana: %', recipeless_names;
        RAISE NOTICE 'recipes holding a cast-type card other than their cast_type: %', diverging_names;
        RAISE NOTICE 'range replaced by the cast range, old value kept as effect_radius: %', preserved_effect_radius;
    END
$$;

DROP TABLE magic_range_collision;

-- Replace the player card without deleting the old magic: match statistics still reference it.
-- Existing owned and deck copies move to Seed Nest, including decks that contain both cards.
-- no-tags: no magic or game object is registered here.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM magics WHERE name = 'seed_spirit_swarm')
        OR NOT EXISTS (SELECT 1 FROM magics WHERE name = 'seed_nest') THEN
        RAISE EXCEPTION 'Seed Spirit Swarm and Seed Nest must both exist';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM (VALUES ('seed_nest'), ('overgrowth')) AS target(name)
        WHERE NOT EXISTS (
            SELECT 1 FROM game_objects go
            JOIN parameter_values pv ON pv.game_object_id = go.id
            JOIN parameters p ON p.id = pv.parameter_id AND p.name = 'mana_cost'
            WHERE go.name = target.name
        )
    ) THEN
        RAISE EXCEPTION 'Seed Nest and Overgrowth must both have mana_cost';
    END IF;
END $$;

INSERT INTO user_magics (user_id, magic_id, count)
SELECT old.user_id, nest.id, old.count
FROM user_magics old
JOIN magics spirit ON spirit.id = old.magic_id AND spirit.name = 'seed_spirit_swarm'
CROSS JOIN magics nest
WHERE nest.name = 'seed_nest'
ON CONFLICT (user_id, magic_id)
DO UPDATE SET count = user_magics.count + EXCLUDED.count;

INSERT INTO deck_cards (deck_id, magic_id, count)
SELECT old.deck_id, nest.id, old.count
FROM deck_cards old
JOIN magics spirit ON spirit.id = old.magic_id AND spirit.name = 'seed_spirit_swarm'
CROSS JOIN magics nest
WHERE nest.name = 'seed_nest'
ON CONFLICT (magic_id, deck_id)
DO UPDATE SET count = deck_cards.count + EXCLUDED.count;

DELETE FROM deck_cards
WHERE magic_id = (SELECT id FROM magics WHERE name = 'seed_spirit_swarm');

DELETE FROM user_magics
WHERE magic_id = (SELECT id FROM magics WHERE name = 'seed_spirit_swarm');

UPDATE magics
SET purpose = 'LEGACY', access_type = 'NONE', updated_at = now()
WHERE name = 'seed_spirit_swarm'
  AND (purpose IS DISTINCT FROM 'LEGACY' OR access_type IS DISTINCT FROM 'NONE');

WITH desired(name, cost) AS (VALUES ('seed_nest', 15), ('overgrowth', 20)),
changed AS (
    UPDATE parameter_values pv
    SET value = desired.cost, updated_at = now()
    FROM desired
    JOIN game_objects go ON go.name = desired.name
    JOIN parameters p ON p.name = 'mana_cost'
    WHERE pv.game_object_id = go.id
      AND pv.parameter_id = p.id
      AND pv.value IS DISTINCT FROM desired.cost::double precision
    RETURNING desired.name
)
UPDATE magics m
SET updated_at = now()
FROM changed
WHERE m.name = changed.name;

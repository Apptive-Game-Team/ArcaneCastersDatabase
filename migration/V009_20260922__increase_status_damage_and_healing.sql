-- Multiply the six damaging or healing status effect amounts by ten.
-- Durations, shock timing, and snare slow percentage are unchanged.
-- V008 remains byte-for-byte identical to the previously published migration.
-- no-tags: this migration registers neither a game object nor a magic.

CREATE TEMP TABLE status_effect_balance (
    parameter_name text PRIMARY KEY,
    amount double precision NOT NULL
) ON COMMIT DROP;

INSERT INTO status_effect_balance (parameter_name, amount)
VALUES
    ('burn_total_damage', 30),
    ('wet_nature_heal', 30),
    ('snare_fire_damage', 50),
    ('leaf_field_heal_amount', 10),
    ('sandstorm_effect_damage', 10),
    ('building_snare_heal', 10);

DO $$
DECLARE
    missing text;
BEGIN
    SELECT string_agg(desired.parameter_name, ', ' ORDER BY desired.parameter_name)
    INTO missing
    FROM status_effect_balance desired
    WHERE NOT EXISTS (
        SELECT 1
        FROM game_objects go
        JOIN parameter_values pv ON pv.game_object_id = go.id
        JOIN parameters p ON p.id = pv.parameter_id
        WHERE go.name = 'game'
          AND p.name = desired.parameter_name
          AND pv.value IS NOT NULL
    );

    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'Missing status effect values: %', missing;
    END IF;
END $$;

UPDATE parameter_values pv
SET value = desired.amount,
    updated_at = now()
FROM status_effect_balance desired
JOIN parameters p ON p.name = desired.parameter_name
JOIN game_objects go ON go.name = 'game'
WHERE pv.parameter_id = p.id
  AND pv.game_object_id = go.id
  AND pv.value IS DISTINCT FROM desired.amount;

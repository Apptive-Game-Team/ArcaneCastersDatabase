-- V029: registers the PVE-only boss prefab PveEvilEnt (object name pve_evil_ent), the corrupted
-- spirit of gate adventure stage 2 (V030). It gets its own game_objects row instead of sharing
-- the card row evil_ent, as V028 did for the toad and tadpoles, so card balance and the boss
-- can be tuned apart.
--   pve_evil_ent  hp 3000 (the scenarios override it per installer with max_hp)
-- Every other key evil_ent carries is copied (mass, radius, speed, attack_range, damage,
-- attack_interval, sub_attack_range, sub_damage, sub_attack_interval, sub_speed,
-- projectile_speed, pull_mass_limit, quantity, range). magic_id and mana_cost are not copied:
-- the boss is not a card (evil_ent has no magic_id row, and mana_cost is skipped by name).
-- prefab_elements are the same two as evil_ent (Fire, Nature).
-- Overridden against the card values, because the boss stands still at x=14 and the left player
-- stands at x=1 (arena x 0..18): attack_range and sub_attack_range are 20, not the card's 5 and 6.
-- With the card ranges the game server's PveEvilEntMob never reaches the player and the boss stands
-- idle (verified by a unit test in game pull request #78). damage 40 (card 90) and sub_damage 200
-- (card 400) are first guesses, lowered because the boss now hits from across the arena; tune by
-- playing.
-- The key list matches what PveEvilEntPrefabInitializer reads (game pull request #78): hp, mass,
-- radius, damage, attack_interval, attack_range, projectile_speed, sub_damage, sub_attack_range,
-- sub_attack_interval, pull_mass_limit. Other copied keys are not read and are harmless.
-- Deploy order: this must apply after V028 and before a game server that spawns PveEvilEnt.
-- Idempotent: game_objects and parameter_values use ON CONFLICT and a second run resets the values.
-- no-tags: the boss is enemy-only and never enters a bot deck, so counter tags do not apply.

INSERT INTO game_objects(name)
VALUES ('pve_evil_ent')
ON CONFLICT (name) DO NOTHING;

WITH copied AS (
    SELECT p.id AS parameter_id, pv.value
    FROM game_objects src
    JOIN parameter_values pv ON pv.game_object_id = src.id
    JOIN parameters p ON p.id = pv.parameter_id
    WHERE src.name = 'evil_ent'
      AND p.name NOT IN ('magic_id', 'mana_cost', 'hp',
                         'attack_range', 'sub_attack_range', 'damage', 'sub_damage')
),
overridden AS (
    SELECT p.id AS parameter_id, v.value
    FROM (VALUES ('hp', 3000.0),
                 ('attack_range', 20.0),
                 ('sub_attack_range', 20.0),
                 ('damage', 40.0),
                 ('sub_damage', 200.0)) AS v(name, value)
    JOIN parameters p ON p.name = v.name
),
merged AS (
    SELECT parameter_id, value FROM copied
    UNION ALL
    SELECT parameter_id, value FROM overridden
)
INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT go.id, m.parameter_id, m.value
FROM merged m
JOIN game_objects go ON go.name = 'pve_evil_ent'
ON CONFLICT (parameter_id, game_object_id)
DO UPDATE SET value = EXCLUDED.value, updated_at = now();

INSERT INTO prefab_elements(prefab, element)
VALUES
    ('pve_evil_ent', 'Fire'),
    ('pve_evil_ent', 'Nature')
ON CONFLICT (prefab, element) DO NOTHING;

SELECT setval('game_objects_id_seq', (SELECT max(id) FROM game_objects));

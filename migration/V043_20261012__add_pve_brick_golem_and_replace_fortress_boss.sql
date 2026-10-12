-- V043: registers the PVE-only boss prefab PveBrickGolem (object name pve_brick_golem) and
-- replaces the fortress adventure's final boss (scenario 13, stage 4) with it. The vine witch
-- is gone from the fortress story: the fortress wall holds a guardian golem that the vines'
-- corruption wakes. Scenario 4 (forest) keeps its witch and is not touched.
--
-- The golem is a stationary upper body with two attacks:
--   slam   (damage, attack_interval, attack_range, effect_radius): picks one ground enemy in
--          range, shows a 1.0 s warning on the spot, then hits a circle of effect_radius there.
--   sweep  (sub_damage, sub_attack_interval, sub_attack_range): a short-range cone in front of
--          the body with knockback.
-- Values were read from the chain replayed on an empty database (live scale), not from memory:
--
--   key                  pve_brick_golem  reference
--   hp                   3250             pve_evil_ent 3000; scenario 13 overrides it per installer
--   radius               1.6              pve_evil_ent 1.2, wall_golem 1.2; larger body than both
--   mass                 1000000          pve_vine_witch 1000000; it never moves, so spells cannot push it
--   damage (slam)        80               2 x pve_evil_ent damage 40
--   attack_interval      4                pve_evil_ent 1.8, wall_golem 2.5; slow because the hit is telegraphed
--   attack_range         14               arena x 0..18, golem at x=14: reaches x=0 only at the very edge
--   effect_radius        1.5              slam circle, about one lane (lanes are 2 apart)
--   sub_damage (sweep)   40               = pve_evil_ent damage 40
--   sub_attack_interval  2.5              wall_golem attack_interval 2.5
--   sub_attack_range     3.5              close range, so the sweep only punishes units that reach the body
--
-- All ten parameters already exist in the baseline. Tune by playing.
-- Deploy order: this must apply before the game server that spawns PveBrickGolem, because the
-- scenario 13 installer names that prefab.
-- Idempotent: game_objects and parameter_values use ON CONFLICT (a second run resets the values),
-- and the scenario 13 changes are UPDATE/DELETE ... WHERE that match nothing the second time.
-- no-tags: the boss is enemy-only and never enters a bot deck, so counter tags do not apply.

INSERT INTO game_objects(name)
VALUES ('pve_brick_golem')
ON CONFLICT (name) DO NOTHING;

INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT go.id, p.id, v.value
FROM (VALUES ('hp', 3250.0),
             ('radius', 1.6),
             ('mass', 1000000.0),
             ('damage', 80.0),
             ('attack_interval', 4.0),
             ('attack_range', 14.0),
             ('effect_radius', 1.5),
             ('sub_damage', 40.0),
             ('sub_attack_interval', 2.5),
             ('sub_attack_range', 3.5)) AS v(name, value)
JOIN parameters p ON p.name = v.name
JOIN game_objects go ON go.name = 'pve_brick_golem'
ON CONFLICT (parameter_id, game_object_id)
DO UPDATE SET value = EXCLUDED.value, updated_at = now();

INSERT INTO prefab_elements(prefab, element)
VALUES ('pve_brick_golem', 'Rock')
ON CONFLICT (prefab, element) DO NOTHING;

SELECT setval('game_objects_id_seq', (SELECT max(id) FROM game_objects));

-- Scenario 13: the boss installer witch (PveVineWitch) becomes golem (PveBrickGolem).
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pve_scenario_installers
                   WHERE scenario_id = 13 AND installer_id = 'golem') THEN
        IF (SELECT count(*) FROM pve_scenario_installers
            WHERE scenario_id = 13 AND installer_id = 'witch' AND prefab_type = 'PveVineWitch') <> 1
           OR (SELECT count(*) FROM pve_scenario_objectives
               WHERE scenario_id = 13 AND installer_id = 'witch') <> 1
           OR (SELECT count(*) FROM pve_scenario_events WHERE scenario_id = 13) <> 6
           OR (SELECT count(*) FROM pve_scenario_event_actions a
               JOIN pve_scenario_events e ON e.id = a.event_row_id
               WHERE e.scenario_id = 13 AND a.installer_id = 'witch') <> 3 THEN
            RAISE EXCEPTION 'scenario 13 does not have the expected witch rows';
        END IF;
    END IF;
END $$;

UPDATE pve_scenario_installers
SET installer_id = 'golem', prefab_type = 'PveBrickGolem'
WHERE scenario_id = 13 AND installer_id = 'witch';

UPDATE pve_scenario_objectives
SET installer_id = 'golem'
WHERE scenario_id = 13 AND installer_id = 'witch';

UPDATE pve_scenario_events
SET target_installer_id = 'golem'
WHERE scenario_id = 13 AND target_installer_id = 'witch';

UPDATE pve_scenario_event_actions
SET installer_id = 'golem'
WHERE installer_id = 'witch'
  AND event_row_id IN (SELECT id FROM pve_scenario_events WHERE scenario_id = 13);

-- The golem never speaks.
UPDATE pve_scenario_events
SET speaker_installer_id = NULL, message_key = NULL
WHERE scenario_id = 13
  AND (speaker_installer_id IS NOT NULL OR message_key IS NOT NULL);

DELETE FROM pve_scenario_event_lines
WHERE event_row_id IN (SELECT id FROM pve_scenario_events WHERE scenario_id = 13);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pve_scenario_installers
                   WHERE scenario_id = 13 AND installer_id = 'golem' AND prefab_type = 'PveBrickGolem')
       OR EXISTS (SELECT 1 FROM pve_scenario_installers
                  WHERE scenario_id = 13 AND installer_id = 'witch')
       OR EXISTS (SELECT 1 FROM pve_scenario_event_actions a
                  JOIN pve_scenario_events e ON e.id = a.event_row_id
                  WHERE e.scenario_id = 13 AND a.installer_id = 'witch')
       OR EXISTS (SELECT 1 FROM pve_scenario_events
                  WHERE scenario_id = 13
                    AND (message_key IS NOT NULL OR speaker_installer_id IS NOT NULL))
       OR (SELECT count(*) FROM parameter_values pv
           JOIN game_objects go ON go.id = pv.game_object_id
           WHERE go.name = 'pve_brick_golem') <> 10 THEN
        RAISE EXCEPTION 'V043 did not produce the expected pve_brick_golem and scenario 13 rows';
    END IF;
END $$;

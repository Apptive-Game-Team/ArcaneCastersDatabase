-- V027: adds the gate adventure (id 3, FREE) with its first stage (id 5) and three scenarios
-- (ids 14-16). Ids are explicit and picked above the current maximum of each table
-- (adventures 2, stages 4, scenarios 13). Fire-realm beings forced the toad species to open
-- dimensional gates; the player destroys the gates. Enemies use only the PVE-only prefabs
-- PveDimensionToad (the stationary gate keeper: never attacks, spawns PveFireTadpole and
-- PveLightningTadpole in turn through the scenario's own events), PveFireTadpole and
-- PveLightningTadpole. Their parameters are registered in V028.
-- All numbers here (wave sizes, gate max_hp 600-1200) are first guesses to be tuned by playing.
-- Scenario 14: one gate. Scenario 15: two gates, the second opens at 15 s, each bursts into a
-- wave when destroyed. Scenario 16: Survive 100 s while more gates keep opening.
-- No end-of-adventure chest, reward or quest rows: those come with stage 2.
-- Tuning: wave sizes and timings sit in one VALUES block per table per scenario.
-- Idempotent: the three ids use ON CONFLICT DO NOTHING and scenario 14-16 content is deleted
-- before it is inserted again.
-- no-tags: no game_objects or magics row is registered here.

-- 1. Adventure, stage and scenario rows.
INSERT INTO adventures (id, name, access_type) VALUES (3, 'gate', 'FREE')
ON CONFLICT (id) DO NOTHING;
INSERT INTO stages (id, adventure_id) VALUES (5, 3)
ON CONFLICT (id) DO NOTHING;
INSERT INTO scenarios (id, stage_id) VALUES (14, 5), (15, 5), (16, 5)
ON CONFLICT (id) DO NOTHING;

-- 2. Content rows of scenarios 14-16 start empty so a second run does not duplicate them.
-- pve_scenario_events cascades to pve_scenario_event_lines and pve_scenario_event_actions.
DELETE FROM pve_scenario_events WHERE scenario_id IN (14, 15, 16);
DELETE FROM pve_scenario_objectives WHERE scenario_id IN (14, 15, 16);
DELETE FROM pve_scenario_rules WHERE scenario_id IN (14, 15, 16);
DELETE FROM pve_scenario_installers WHERE scenario_id IN (14, 15, 16);

-- ---- scenario 14: one gate ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('gate_a', 'PveDimensionToad', 'RightPlayer', 14, 0, 5, 800, 1, 14);

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('gate_a', 1, 14);

INSERT INTO pve_scenario_rules (scenario_id, win_condition, survive_seconds) VALUES
    (14, 'DestroyObjectives', NULL);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_14_intro', 1, 14),
    ('wave_1', 'SecondsGte', 30, NULL::text, NULL::text, NULL::text, 2, 14),
    ('wave_2', 'SecondsGte', 60, NULL::text, NULL::text, NULL::text, 3, 14);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'A gate is open. Stop whoever is holding it!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 14;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp
FROM (VALUES
    ('wave_1', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 2, NULL::real, 14, 3, NULL::integer),
    ('wave_1', 2, 'SpawnWave', NULL::text, 'PveLightningTadpole', 2, NULL::real, 14, 7, NULL::integer),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 3, NULL::real, 14, 3, NULL::integer),
    ('wave_2', 2, 'SpawnWave', NULL::text, 'PveLightningTadpole', 3, NULL::real, 14, 7, NULL::integer)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 14;

-- ---- scenario 15: two gates ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('gate_a', 'PveDimensionToad', 'RightPlayer', 14, 0, 3, 600, 1, 15);

-- gate_b is installed by the gate_b_open event; an objective installed later counts once it exists.
INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('gate_a', 1, 15),
    ('gate_b', 2, 15);

INSERT INTO pve_scenario_rules (scenario_id, win_condition, survive_seconds) VALUES
    (15, 'DestroyObjectives', NULL);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('gate_b_open', 'SecondsGte', 15, NULL::text, NULL::text, 'pve_15_gate_b_open', 1, 15),
    ('gate_a_dead', 'InstallerDestroyed', 0, 'gate_a', NULL::text, 'pve_15_gate_a_dead', 2, 15),
    ('gate_b_dead', 'InstallerDestroyed', 0, 'gate_b', NULL::text, 'pve_15_gate_b_dead', 3, 15);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('gate_b_open', 'A second gate opens!'),
    ('gate_a_dead', 'The gate bursts!'),
    ('gate_b_dead', 'The gate bursts!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 15;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp
FROM (VALUES
    ('gate_b_open', 1, 'InstallObject', 'gate_b', 'PveDimensionToad', NULL::integer, NULL::real, 14, 7, 600),
    ('gate_a_dead', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 3, NULL::real, 14, 5, NULL::integer),
    ('gate_a_dead', 2, 'SpawnWave', NULL::text, 'PveLightningTadpole', 3, NULL::real, 14, 5, NULL::integer),
    ('gate_b_dead', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 3, NULL::real, 14, 5, NULL::integer),
    ('gate_b_dead', 2, 'SpawnWave', NULL::text, 'PveLightningTadpole', 3, NULL::real, 14, 5, NULL::integer)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 15;

-- ---- scenario 16: gates keep opening (Survive 100 s) ----
-- gate_1 is the objective row that lets the scenario load, as in scenarios 3 and 11 (V015);
-- destroying it clears the scenario early.
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('gate_1', 'PveDimensionToad', 'RightPlayer', 14, 0, 5, 1200, 1, 16);

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('gate_1', 1, 16);

INSERT INTO pve_scenario_rules (scenario_id, win_condition, survive_seconds) VALUES
    (16, 'Survive', 100);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_16_intro', 1, 16),
    ('gate_2_open', 'SecondsGte', 20, NULL::text, NULL::text, 'pve_16_gate_2_open', 2, 16),
    ('gate_3_open', 'SecondsGte', 40, NULL::text, NULL::text, NULL::text, 3, 16),
    ('warn_40', 'SecondsGte', 60, NULL::text, NULL::text, 'pve_16_warn_40', 4, 16),
    ('gate_4_open', 'SecondsGte', 60, NULL::text, NULL::text, NULL::text, 5, 16),
    ('gate_5_open', 'SecondsGte', 80, NULL::text, NULL::text, NULL::text, 6, 16),
    ('gate_2_dead', 'InstallerDestroyed', 0, 'gate_2', NULL::text, NULL::text, 7, 16),
    ('gate_3_dead', 'InstallerDestroyed', 0, 'gate_3', NULL::text, NULL::text, 8, 16),
    ('gate_4_dead', 'InstallerDestroyed', 0, 'gate_4', NULL::text, NULL::text, 9, 16),
    ('gate_5_dead', 'InstallerDestroyed', 0, 'gate_5', NULL::text, NULL::text, 10, 16);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'The gates will not stop. Survive for 100 seconds!'),
    ('gate_2_open', 'Another gate opens!'),
    ('warn_40', 'Forty seconds left!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 16;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp
FROM (VALUES
    ('gate_2_open', 1, 'InstallObject', 'gate_2', 'PveDimensionToad', NULL::integer, NULL::real, 14, 3, 600),
    ('gate_3_open', 1, 'InstallObject', 'gate_3', 'PveDimensionToad', NULL::integer, NULL::real, 14, 7, 600),
    ('gate_4_open', 1, 'InstallObject', 'gate_4', 'PveDimensionToad', NULL::integer, NULL::real, 14, 4, 600),
    ('gate_5_open', 1, 'InstallObject', 'gate_5', 'PveDimensionToad', NULL::integer, NULL::real, 14, 6, 600),
    ('gate_2_dead', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 2, NULL::real, 14, 5, NULL::integer),
    ('gate_2_dead', 2, 'SpawnWave', NULL::text, 'PveLightningTadpole', 2, NULL::real, 14, 5, NULL::integer),
    ('gate_3_dead', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 2, NULL::real, 14, 5, NULL::integer),
    ('gate_3_dead', 2, 'SpawnWave', NULL::text, 'PveLightningTadpole', 2, NULL::real, 14, 5, NULL::integer),
    ('gate_4_dead', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 2, NULL::real, 14, 5, NULL::integer),
    ('gate_4_dead', 2, 'SpawnWave', NULL::text, 'PveLightningTadpole', 2, NULL::real, 14, 5, NULL::integer),
    ('gate_5_dead', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 2, NULL::real, 14, 5, NULL::integer),
    ('gate_5_dead', 2, 'SpawnWave', NULL::text, 'PveLightningTadpole', 2, NULL::real, 14, 5, NULL::integer)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 16;

-- 3. Sequences for every table this migration inserted into.
SELECT setval('adventures_id_seq', (SELECT max(id) FROM adventures));
SELECT setval('stages_id_seq', (SELECT max(id) FROM stages));
SELECT setval('scenarios_id_seq', (SELECT max(id) FROM scenarios));
SELECT setval('pve_scenario_installers_id_seq', (SELECT max(id) FROM pve_scenario_installers));
SELECT setval('pve_scenario_objectives_id_seq', (SELECT max(id) FROM pve_scenario_objectives));
SELECT setval('pve_scenario_events_id_seq', (SELECT max(id) FROM pve_scenario_events));
SELECT setval('pve_scenario_event_lines_id_seq', (SELECT max(id) FROM pve_scenario_event_lines));
SELECT setval('pve_scenario_event_actions_id_seq', (SELECT max(id) FROM pve_scenario_event_actions));

-- V030: adds stage 2 (id 6) of the gate adventure (id 3, V027) with two scenarios (ids 17, 18).
-- Ids are explicit and picked above the current maximum of each table (stages 5, scenarios 16).
-- The gates are held open by a captured species; the evil ent is a spirit corrupted by hellfire
-- exposure, and it draws its power from the gates. Each scenario's boss (installer corrupted,
-- PveEvilEnt, registered in V029) is the only objective and is shielded (V026
-- pve_scenario_shields) while any of its source gates (PveDimensionToad) lives. Tadpole waves
-- use PveFireTadpole and PveLightningTadpole (V028). The boss never speaks: events without a
-- speaker are banners.
-- Scenario 17: boss max_hp 3000, two gates at the start (hp 600 each), waves at 30 s and 60 s.
-- Scenario 18 (finale): boss max_hp 4500, two gates at the start; at 50 % boss hp two more gates
-- (gate_c, gate_d, hp 500) open and shield it again; at 25 % a final wave.
-- All numbers here are first guesses to be tuned by playing. Tuning: wave sizes and timings sit
-- in one VALUES block per table per scenario.
-- Message keys: pve_17_intro, pve_17_gate_a_dead, pve_17_gate_b_dead, pve_18_intro,
-- pve_18_gate_a_dead, pve_18_gate_b_dead, pve_18_phase_50, pve_18_gate_c_dead, pve_18_gate_d_dead.
-- Deploy order: apply after V026-V029 and before a game server that spawns PveEvilEnt.
-- No reward rows here: the adventure chest and quest come with V031.
-- Idempotent: the ids use ON CONFLICT DO NOTHING and scenario 17-18 content is deleted before it
-- is inserted again.
-- no-tags: no game_objects or magics row is registered here.

-- 1. Stage and scenario rows.
INSERT INTO stages (id, adventure_id) VALUES (6, 3)
ON CONFLICT (id) DO NOTHING;
INSERT INTO scenarios (id, stage_id) VALUES (17, 6), (18, 6)
ON CONFLICT (id) DO NOTHING;

-- 2. Content rows of scenarios 17-18 start empty so a second run does not duplicate them.
-- pve_scenario_events cascades to pve_scenario_event_lines and pve_scenario_event_actions.
DELETE FROM pve_scenario_events WHERE scenario_id IN (17, 18);
DELETE FROM pve_scenario_objectives WHERE scenario_id IN (17, 18);
DELETE FROM pve_scenario_rules WHERE scenario_id IN (17, 18);
DELETE FROM pve_scenario_shields WHERE scenario_id IN (17, 18);
DELETE FROM pve_scenario_installers WHERE scenario_id IN (17, 18);

-- ---- scenario 17: the spirit and two gates ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('corrupted', 'PveEvilEnt', 'RightPlayer', 14, 0, 5, 3000, 1, 17),
    ('gate_a', 'PveDimensionToad', 'RightPlayer', 14, 0, 3, 600, 2, 17),
    ('gate_b', 'PveDimensionToad', 'RightPlayer', 14, 0, 7, 600, 3, 17);

INSERT INTO pve_scenario_shields (scenario_id, installer_id, source_installer_id) VALUES
    (17, 'corrupted', 'gate_a'),
    (17, 'corrupted', 'gate_b');

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('corrupted', 1, 17);

INSERT INTO pve_scenario_rules (scenario_id, win_condition, survive_seconds) VALUES
    (17, 'DestroyObjectives', NULL);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_17_intro', 1, 17),
    ('gate_a_dead', 'InstallerDestroyed', 0, 'gate_a', NULL::text, 'pve_17_gate_a_dead', 2, 17),
    ('gate_b_dead', 'InstallerDestroyed', 0, 'gate_b', NULL::text, 'pve_17_gate_b_dead', 3, 17),
    ('wave_1', 'SecondsGte', 30, NULL::text, NULL::text, NULL::text, 4, 17),
    ('wave_2', 'SecondsGte', 60, NULL::text, NULL::text, NULL::text, 5, 17);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'The corrupted spirit draws its power from the gates!'),
    ('gate_a_dead', 'A gate closes!'),
    ('gate_b_dead', 'A gate closes!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 17;

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
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 17;

-- ---- scenario 18: finale, the gates open again at half health ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('corrupted', 'PveEvilEnt', 'RightPlayer', 14, 0, 5, 4500, 1, 18),
    ('gate_a', 'PveDimensionToad', 'RightPlayer', 14, 0, 3, 600, 2, 18),
    ('gate_b', 'PveDimensionToad', 'RightPlayer', 14, 0, 7, 600, 3, 18);

-- gate_c and gate_d are installed by the phase_50 event; a source counts once it is installed.
INSERT INTO pve_scenario_shields (scenario_id, installer_id, source_installer_id) VALUES
    (18, 'corrupted', 'gate_a'),
    (18, 'corrupted', 'gate_b'),
    (18, 'corrupted', 'gate_c'),
    (18, 'corrupted', 'gate_d');

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('corrupted', 1, 18);

INSERT INTO pve_scenario_rules (scenario_id, win_condition, survive_seconds) VALUES
    (18, 'DestroyObjectives', NULL);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_18_intro', 1, 18),
    ('gate_a_dead', 'InstallerDestroyed', 0, 'gate_a', NULL::text, 'pve_18_gate_a_dead', 2, 18),
    ('gate_b_dead', 'InstallerDestroyed', 0, 'gate_b', NULL::text, 'pve_18_gate_b_dead', 3, 18),
    ('wave_1', 'SecondsGte', 30, NULL::text, NULL::text, NULL::text, 4, 18),
    ('phase_50', 'InstallerHpPercentLte', 50, 'corrupted', NULL::text, 'pve_18_phase_50', 5, 18),
    ('gate_c_dead', 'InstallerDestroyed', 0, 'gate_c', NULL::text, 'pve_18_gate_c_dead', 6, 18),
    ('gate_d_dead', 'InstallerDestroyed', 0, 'gate_d', NULL::text, 'pve_18_gate_d_dead', 7, 18),
    ('phase_25', 'InstallerHpPercentLte', 25, 'corrupted', NULL::text, NULL::text, 8, 18);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'The spirit has taken in more fire. Close the gates!'),
    ('gate_a_dead', 'A gate closes!'),
    ('gate_b_dead', 'A gate closes!'),
    ('phase_50', 'The gates open again!'),
    ('gate_c_dead', 'A gate closes!'),
    ('gate_d_dead', 'A gate closes!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 18;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp
FROM (VALUES
    ('wave_1', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 2, NULL::real, 14, 3, NULL::integer),
    ('wave_1', 2, 'SpawnWave', NULL::text, 'PveLightningTadpole', 2, NULL::real, 14, 7, NULL::integer),
    ('phase_50', 1, 'InstallObject', 'gate_c', 'PveDimensionToad', NULL::integer, NULL::real, 14, 2, 500),
    ('phase_50', 2, 'InstallObject', 'gate_d', 'PveDimensionToad', NULL::integer, NULL::real, 14, 8, 500),
    ('phase_25', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 3, NULL::real, 14, 3, NULL::integer),
    ('phase_25', 2, 'SpawnWave', NULL::text, 'PveLightningTadpole', 3, NULL::real, 14, 7, NULL::integer)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 18;

-- 3. Sequences for every table this migration inserted into.
SELECT setval('stages_id_seq', (SELECT max(id) FROM stages));
SELECT setval('scenarios_id_seq', (SELECT max(id) FROM scenarios));
SELECT setval('pve_scenario_installers_id_seq', (SELECT max(id) FROM pve_scenario_installers));
SELECT setval('pve_scenario_objectives_id_seq', (SELECT max(id) FROM pve_scenario_objectives));
SELECT setval('pve_scenario_events_id_seq', (SELECT max(id) FROM pve_scenario_events));
SELECT setval('pve_scenario_event_lines_id_seq', (SELECT max(id) FROM pve_scenario_event_lines));
SELECT setval('pve_scenario_event_actions_id_seq', (SELECT max(id) FROM pve_scenario_event_actions));

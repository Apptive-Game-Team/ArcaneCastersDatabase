-- V013: reworks the forest adventure's scenarios 1-4 with the V012 PVE engine (per-installer
-- hp override, hp/death triggers, SpawnWave/InstallObject/SetSpawner actions, Survive win
-- condition), adds forest stage 2 (scenarios 5-7), and adds the fortress adventure (id 2,
-- FREE, stage 3-4, scenarios 8-13). Design table: issue #48.
-- no-tags: no game_objects or magics row is registered here.

-- 1. Delete the forest scenario 1-4 CONTENT rows only. adventures(1), stages(1) and
-- scenarios(1-4) keep their ids so existing user_scenarios/user_stages progress survives.
-- pve_scenario_events cascades to pve_scenario_event_lines and pve_scenario_event_actions.
DELETE FROM pve_scenario_events WHERE scenario_id IN (1, 2, 3, 4);
DELETE FROM pve_scenario_objectives WHERE scenario_id IN (1, 2, 3, 4);
DELETE FROM pve_scenario_rules WHERE scenario_id IN (1, 2, 3, 4);
DELETE FROM pve_scenario_installers WHERE scenario_id IN (1, 2, 3, 4);

-- 2. Forest stage 2 and the fortress adventure's stages/scenarios. Ids are explicit and
-- picked above the current maximum of each table.
INSERT INTO stages (id, adventure_id) VALUES (2, 1);

INSERT INTO adventures (id, name, access_type) VALUES (2, 'fortress', 'FREE');
INSERT INTO stages (id, adventure_id) VALUES (3, 2), (4, 2);

INSERT INTO scenarios (id, stage_id) VALUES
    (5, 2), (6, 2), (7, 2),
    (8, 3), (9, 3), (10, 3),
    (11, 4), (12, 4), (13, 4);

-- ---- scenario 1 (stage 1) ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('nest', 'PveNatureSlimeNest', 'RightPlayer', 14, 0, 5, 800, 1, 1);

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('nest', 1, 1);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, 'nest', 'pve_1_intro', 1, 1),
    ('wave_1', 'SecondsGte', 20, NULL::text, NULL::text, NULL::text, 2, 1),
    ('wave_2', 'SecondsGte', 45, NULL::text, NULL::text, NULL::text, 3, 1),
    ('wave_3', 'SecondsGte', 70, NULL::text, NULL::text, NULL::text, 4, 1),
    ('phase_50', 'InstallerHpPercentLte', 50, 'nest', 'nest', 'pve_1_phase_50', 5, 1);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'Slimes are pouring out of that nest. Break it!'),
    ('phase_50', 'Squish! Squish!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 1;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp
FROM (VALUES
    ('wave_1', 1, 'SpawnWave', NULL::text, 'LeafSlime', 6, NULL::real, 14, 5, NULL::integer),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'LeafSlime', 9, NULL::real, 14, 3, NULL::integer),
    ('wave_3', 1, 'SpawnWave', NULL::text, 'LeafSlime', 9, NULL::real, 14, 7, NULL::integer),
    ('phase_50', 1, 'SpawnWave', NULL::text, 'LeafSlime', 12, NULL::real, 14, 5, NULL::integer)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 1;

-- ---- scenario 2 (stage 1) ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('nature_nest', 'PveNatureSlimeNest', 'RightPlayer', 14, 0, 7, 800, 1, 2),
    ('water_nest', 'PveWaterSlimeNest', 'RightPlayer', 14, 0, 3, 800, 2, 2);

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('nature_nest', 1, 2),
    ('water_nest', 2, 2);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_2_intro', 1, 2),
    ('wave_1', 'SecondsGte', 25, NULL::text, NULL::text, NULL::text, 2, 2),
    ('wave_2', 'SecondsGte', 50, NULL::text, NULL::text, NULL::text, 3, 2),
    ('nature_dead', 'InstallerDestroyed', 0, 'nature_nest', 'water_nest', 'pve_2_nature_dead', 4, 2);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'Two nests this time. Mind both lanes.'),
    ('nature_dead', 'You''ll pay for that!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 2;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp
FROM (VALUES
    ('wave_1', 1, 'SpawnWave', NULL::text, 'WaterSlime', 8, NULL::real, 14, 3, NULL::integer),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'LeafSlime', 8, NULL::real, 14, 7, NULL::integer),
    ('nature_dead', 1, 'SetSpawner', 'water_nest', 'WaterSlime', 3, 8, NULL::integer, NULL::integer, NULL::integer),
    ('nature_dead', 2, 'SpawnWave', NULL::text, 'WaterSlime', 9, NULL::real, 14, 5, NULL::integer)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 2;

-- ---- scenario 3 (stage 1) ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('colony', 'PveVineColony', 'RightPlayer', 14, 0, 5, 3000, 1, 3);

INSERT INTO pve_scenario_rules (scenario_id, win_condition, survive_seconds) VALUES (3, 'Survive', 90);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_3_intro', 1, 3),
    ('wave_1', 'SecondsGte', 10, NULL::text, NULL::text, NULL::text, 2, 3),
    ('wave_2', 'SecondsGte', 25, NULL::text, NULL::text, NULL::text, 3, 3),
    ('wave_3', 'SecondsGte', 40, NULL::text, NULL::text, NULL::text, 4, 3),
    ('wave_4', 'SecondsGte', 55, NULL::text, NULL::text, NULL::text, 5, 3),
    ('warn_30', 'SecondsGte', 60, NULL::text, NULL::text, 'pve_3_warn_30', 6, 3),
    ('wave_5', 'SecondsGte', 75, NULL::text, NULL::text, NULL::text, 7, 3),
    ('warn_10', 'SecondsGte', 80, NULL::text, NULL::text, 'pve_3_warn_10', 8, 3);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'The colony is too tough. Hold out for 90 seconds!'),
    ('warn_30', '30 seconds left!'),
    ('warn_10', '10 more seconds!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 3;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp
FROM (VALUES
    ('intro', 1, 'SetSpawner', 'colony', NULL::text, 0, NULL::real, NULL::integer, NULL::integer, NULL::integer),
    ('wave_1', 1, 'SpawnWave', NULL::text, 'LeafSlime', 6, NULL::real, 14, 5, NULL::integer),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'VineSpirit', 3, NULL::real, 14, 3, NULL::integer),
    ('wave_3', 1, 'SpawnWave', NULL::text, 'WaterSlime', 9, NULL::real, 14, 7, NULL::integer),
    ('wave_4', 1, 'SpawnWave', NULL::text, 'VineSpirit', 3, NULL::real, 14, 7, NULL::integer),
    ('wave_4', 2, 'SpawnWave', NULL::text, 'LeafSlime', 6, NULL::real, 14, 5, NULL::integer),
    ('wave_5', 1, 'SpawnWave', NULL::text, 'VineSpirit', 5, NULL::real, 14, 5, NULL::integer)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 3;

-- ---- scenario 4 (stage 1) ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('witch', 'PveVineWitch', 'RightPlayer', 14, 0, 5, 1950, 1, 4);

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('witch', 1, 4);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, 'witch', 'pve_4_intro', 1, 4),
    ('wave_1', 'SecondsGte', 30, NULL::text, NULL::text, NULL::text, 2, 4),
    ('phase_60', 'InstallerHpPercentLte', 60, 'witch', 'witch', 'pve_4_phase_60', 3, 4),
    ('phase_30', 'InstallerHpPercentLte', 30, 'witch', 'witch', 'pve_4_phase_30', 4, 4);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'Heh... you made it this far?'),
    ('phase_60', 'Enough games!'),
    ('phase_30', 'Rise, my garden!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 4;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp
FROM (VALUES
    ('wave_1', 1, 'SpawnWave', NULL::text, 'LeafSlime', 6, NULL::real, 14, 3, NULL::integer),
    ('phase_60', 1, 'SetSpawner', 'witch', 'VineSpirit', 3, 12, NULL::integer, NULL::integer, NULL::integer),
    ('phase_60', 2, 'SpawnWave', NULL::text, 'LeafSlime', 9, NULL::real, 14, 3, NULL::integer),
    ('phase_30', 1, 'SetSpawner', 'witch', 'LeafSlime', 3, 8, NULL::integer, NULL::integer, NULL::integer),
    ('phase_30', 2, 'InstallObject', 'colony_guard', 'PveVineColony', NULL::integer, NULL::real, 14, 7, 500),
    ('phase_30', 3, 'SpawnWave', NULL::text, 'VineSpirit', 3, NULL::real, 14, 5, NULL::integer)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 4;

-- ---- scenario 5 (stage 2) ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('seed_nest', 'PveNatureSlimeNest', 'RightPlayer', 14, 0, 5, 1300, 1, 5);

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('seed_nest', 1, 5);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_5_intro', 1, 5),
    ('wave_1', 'SecondsGte', 30, NULL::text, NULL::text, NULL::text, 2, 5),
    ('wave_2', 'SecondsGte', 60, NULL::text, NULL::text, NULL::text, 3, 5),
    ('wave_3', 'SecondsGte', 90, NULL::text, NULL::text, NULL::text, 4, 5),
    ('phase_50', 'InstallerHpPercentLte', 50, 'seed_nest', 'seed_nest', 'pve_5_phase_50', 5, 5);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'Something heavy is walking this way...'),
    ('phase_50', 'Guardians, protect the nest!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 5;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp
FROM (VALUES
    ('intro', 1, 'SetSpawner', 'seed_nest', 'SeedSpirit', 5, 12, NULL::integer, NULL::integer, NULL::integer),
    ('wave_1', 1, 'SpawnWave', NULL::text, 'TreeGolem', 2, NULL::real, 14, 3, NULL::integer),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'TreeGolem', 2, NULL::real, 14, 7, NULL::integer),
    ('wave_2', 2, 'SpawnWave', NULL::text, 'LeafSlime', 6, NULL::real, 14, 5, NULL::integer),
    ('wave_3', 1, 'SpawnWave', NULL::text, 'SeedSpirit', 6, NULL::real, 14, 3, NULL::integer),
    ('phase_50', 1, 'SpawnWave', NULL::text, 'TreeGolem', 2, NULL::real, 14, 3, NULL::integer),
    ('phase_50', 2, 'SpawnWave', NULL::text, 'TreeGolem', 2, NULL::real, 14, 7, NULL::integer)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 5;

-- ---- scenario 6 (stage 2) ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('outer', 'PveVineColony', 'RightPlayer', 14, 0, 5, 800, 1, 6);

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('outer', 1, 6),
    ('spring', 2, 6);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_6_intro', 1, 6),
    ('wave_1', 'SecondsGte', 15, NULL::text, NULL::text, NULL::text, 2, 6),
    ('wave_2', 'SecondsGte', 40, NULL::text, NULL::text, NULL::text, 3, 6),
    ('wave_3', 'SecondsGte', 65, NULL::text, NULL::text, NULL::text, 4, 6),
    ('outer_dead', 'InstallerDestroyed', 0, 'outer', NULL::text, 'pve_6_outer_dead', 5, 6);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'Cut the roots and the spring will show itself.'),
    ('outer_dead', 'The spring awakens!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 6;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp
FROM (VALUES
    ('intro', 1, 'SetSpawner', 'outer', NULL::text, 0, NULL::real, NULL::integer, NULL::integer, NULL::integer),
    ('wave_1', 1, 'SpawnWave', NULL::text, 'VineSpirit', 3, NULL::real, 14, 3, NULL::integer),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'VineSpirit', 3, NULL::real, 14, 7, NULL::integer),
    ('wave_3', 1, 'SpawnWave', NULL::text, 'VineSpirit', 3, NULL::real, 14, 3, NULL::integer),
    ('wave_3', 2, 'SpawnWave', NULL::text, 'LeafSlime', 6, NULL::real, 14, 5, NULL::integer),
    ('outer_dead', 1, 'InstallObject', 'spring', 'PveWaterSlimeNest', NULL::integer, NULL::real, 14, 3, 1300),
    ('outer_dead', 2, 'SpawnWave', NULL::text, 'WaterSlime', 9, NULL::real, 14, 7, NULL::integer)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 6;

-- ---- scenario 7 (stage 2) ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('witch', 'PveVineWitch', 'RightPlayer', 14, 0, 5, 3250, 1, 7);

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('witch', 1, 7);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, 'witch', 'pve_7_intro', 1, 7),
    ('wave_1', 'SecondsGte', 30, NULL::text, NULL::text, NULL::text, 2, 7),
    ('wave_2', 'SecondsGte', 60, NULL::text, NULL::text, NULL::text, 3, 7),
    ('phase_70', 'InstallerHpPercentLte', 70, 'witch', 'witch', 'pve_7_phase_70', 4, 7),
    ('phase_40', 'InstallerHpPercentLte', 40, 'witch', 'witch', 'pve_7_phase_40', 5, 7),
    ('phase_15', 'InstallerHpPercentLte', 15, 'witch', 'witch', 'pve_7_phase_15', 6, 7);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'So you are the one burning my forest.'),
    ('phase_70', 'Wake, old one!'),
    ('phase_40', 'My nests, rise!'),
    ('phase_15', 'This forest is MINE!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 7;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp
FROM (VALUES
    ('intro', 1, 'SetSpawner', 'witch', 'LeafSlime', 3, 8, NULL::integer, NULL::integer, NULL::integer),
    ('wave_1', 1, 'SpawnWave', NULL::text, 'SeedSpirit', 6, NULL::real, 14, 3, NULL::integer),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'SeedSpirit', 6, NULL::real, 14, 7, NULL::integer),
    ('phase_70', 1, 'SpawnWave', NULL::text, 'EvilEnt', 2, NULL::real, 14, 5, NULL::integer),
    ('phase_40', 1, 'InstallObject', 'nest_a', 'PveNatureSlimeNest', NULL::integer, NULL::real, 14, 3, 650),
    ('phase_40', 2, 'InstallObject', 'nest_b', 'PveWaterSlimeNest', NULL::integer, NULL::real, 14, 7, 650),
    ('phase_40', 3, 'SetSpawner', 'witch', 'VineSpirit', 3, 10, NULL::integer, NULL::integer, NULL::integer),
    ('phase_15', 1, 'SetSpawner', 'witch', NULL::text, 0, NULL::real, NULL::integer, NULL::integer, NULL::integer),
    ('phase_15', 2, 'SpawnWave', NULL::text, 'TreeGolem', 2, NULL::real, 14, 3, NULL::integer),
    ('phase_15', 3, 'SpawnWave', NULL::text, 'TreeGolem', 2, NULL::real, 14, 7, NULL::integer),
    ('phase_15', 4, 'SpawnWave', NULL::text, 'LeafSlime', 9, NULL::real, 14, 5, NULL::integer)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 7;

-- ---- scenario 8 (stage 3) ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('gate_tower', 'GroundCannon', 'RightPlayer', 14, 0, 5, 1050, 1, 8);

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('gate_tower', 1, 8);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_8_intro', 1, 8),
    ('wave_1', 'SecondsGte', 20, NULL::text, NULL::text, NULL::text, 2, 8),
    ('wave_2', 'SecondsGte', 45, NULL::text, NULL::text, NULL::text, 3, 8),
    ('wave_3', 'SecondsGte', 70, NULL::text, NULL::text, NULL::text, 4, 8),
    ('phase_50', 'InstallerHpPercentLte', 50, 'gate_tower', NULL::text, 'pve_8_phase_50', 5, 8);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'The gate tower still fires. Stay out of its reach and break it.'),
    ('phase_50', 'The wall is cracking!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 8;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp
FROM (VALUES
    ('wave_1', 1, 'SpawnWave', NULL::text, 'MiniRock', 3, NULL::real, 14, 3, NULL::integer),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'RockSlime', 6, NULL::real, 14, 7, NULL::integer),
    ('wave_3', 1, 'SpawnWave', NULL::text, 'MiniRock', 3, NULL::real, 14, 5, NULL::integer),
    ('wave_3', 2, 'SpawnWave', NULL::text, 'RockSlime', 5, NULL::real, 14, 3, NULL::integer),
    ('phase_50', 1, 'SpawnWave', NULL::text, 'MiniRock', 3, NULL::real, 14, 7, NULL::integer)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 8;

-- ---- scenario 9 (stage 3) ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('tower_a', 'GroundCannon', 'RightPlayer', 14, 0, 3, 800, 1, 9),
    ('tower_b', 'GroundCannon', 'RightPlayer', 14, 0, 7, 800, 2, 9);

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('tower_a', 1, 9),
    ('tower_b', 2, 9);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_9_intro', 1, 9),
    ('wave_1', 'SecondsGte', 25, NULL::text, NULL::text, NULL::text, 2, 9),
    ('wave_2', 'SecondsGte', 50, NULL::text, NULL::text, NULL::text, 3, 9),
    ('wave_3', 'SecondsGte', 75, NULL::text, NULL::text, NULL::text, 4, 9),
    ('tower_a_dead', 'InstallerDestroyed', 0, 'tower_a', NULL::text, 'pve_9_tower_a_dead', 5, 9);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'Two towers guard the wall.'),
    ('tower_a_dead', 'The other tower turns toward you!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 9;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp
FROM (VALUES
    ('wave_1', 1, 'SpawnWave', NULL::text, 'RockMage', 2, NULL::real, 14, 5, NULL::integer),
    ('wave_1', 2, 'SpawnWave', NULL::text, 'RockSlime', 5, NULL::real, 14, 5, NULL::integer),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'MiniRock', 3, NULL::real, 14, 3, NULL::integer),
    ('wave_3', 1, 'SpawnWave', NULL::text, 'RockMage', 2, NULL::real, 14, 7, NULL::integer),
    ('tower_a_dead', 1, 'SpawnWave', NULL::text, 'RockMage', 2, NULL::real, 14, 7, NULL::integer),
    ('tower_a_dead', 2, 'SpawnWave', NULL::text, 'RockSlime', 5, NULL::real, 14, 7, NULL::integer)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 9;

-- ---- scenario 10 (stage 3) ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('golem', 'WallGolem', 'RightPlayer', 14, 0, 5, 2350, 1, 10);

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('golem', 1, 10);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_10_intro', 1, 10),
    ('wave_1', 'SecondsGte', 20, NULL::text, NULL::text, NULL::text, 2, 10),
    ('wave_2', 'SecondsGte', 40, NULL::text, NULL::text, NULL::text, 3, 10),
    ('phase_60', 'InstallerHpPercentLte', 60, 'golem', 'golem', 'pve_10_phase_60', 4, 10),
    ('phase_30', 'InstallerHpPercentLte', 30, 'golem', NULL::text, 'pve_10_phase_30', 5, 10);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'The gatekeeper wakes.'),
    ('phase_60', 'Grrrraaah!'),
    ('phase_30', 'Defend the gate!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 10;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp
FROM (VALUES
    ('wave_1', 1, 'SpawnWave', NULL::text, 'RockSlime', 6, NULL::real, 14, 3, NULL::integer),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'RockSlime', 6, NULL::real, 14, 7, NULL::integer),
    ('phase_60', 1, 'SpawnWave', NULL::text, 'MiniRock', 3, NULL::real, 14, 3, NULL::integer),
    ('phase_60', 2, 'SpawnWave', NULL::text, 'MiniRock', 3, NULL::real, 14, 7, NULL::integer),
    ('phase_30', 1, 'InstallObject', 'last_tower', 'GroundCannon', NULL::integer, NULL::real, 14, 5, 500),
    ('phase_30', 2, 'SpawnWave', NULL::text, 'RockMage', 2, NULL::real, 14, 3, NULL::integer)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 10;

-- ---- scenario 11 (stage 4) ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('keep_gate', 'GroundCannon', 'RightPlayer', 14, 0, 5, 3000, 1, 11);

INSERT INTO pve_scenario_rules (scenario_id, win_condition, survive_seconds) VALUES (11, 'Survive', 100);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_11_intro', 1, 11),
    ('wave_1', 'SecondsGte', 10, NULL::text, NULL::text, NULL::text, 2, 11),
    ('wave_2', 'SecondsGte', 25, NULL::text, NULL::text, NULL::text, 3, 11),
    ('wave_3', 'SecondsGte', 40, NULL::text, NULL::text, NULL::text, 4, 11),
    ('wave_4', 'SecondsGte', 55, NULL::text, NULL::text, NULL::text, 5, 11),
    ('warn_30', 'SecondsGte', 70, NULL::text, NULL::text, 'pve_11_warn_30', 6, 11),
    ('wave_5', 'SecondsGte', 72, NULL::text, NULL::text, NULL::text, 7, 11),
    ('wave_6', 'SecondsGte', 85, NULL::text, NULL::text, NULL::text, 8, 11),
    ('warn_10', 'SecondsGte', 90, NULL::text, NULL::text, 'pve_11_warn_10', 9, 11);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'The forge is lit. Survive for 100 seconds!'),
    ('warn_30', '30 seconds left!'),
    ('warn_10', '10 more seconds!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 11;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp
FROM (VALUES
    ('wave_1', 1, 'SpawnWave', NULL::text, 'EmberSpirit', 8, NULL::real, 14, 5, NULL::integer),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'FireChildSpirit', 3, NULL::real, 14, 3, NULL::integer),
    ('wave_3', 1, 'SpawnWave', NULL::text, 'FireSpirit', 2, NULL::real, 14, 7, NULL::integer),
    ('wave_4', 1, 'SpawnWave', NULL::text, 'EmberSpirit', 8, NULL::real, 14, 3, NULL::integer),
    ('wave_4', 2, 'SpawnWave', NULL::text, 'FireChildSpirit', 3, NULL::real, 14, 7, NULL::integer),
    ('wave_5', 1, 'SpawnWave', NULL::text, 'FireSpirit', 2, NULL::real, 14, 5, NULL::integer),
    ('wave_6', 1, 'SpawnWave', NULL::text, 'EmberSpirit', 9, NULL::real, 14, 7, NULL::integer)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 11;

-- ---- scenario 12 (stage 4) ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('root_a', 'PveVineColony', 'RightPlayer', 14, 0, 3, 1050, 1, 12),
    ('root_b', 'PveVineColony', 'RightPlayer', 14, 0, 7, 1050, 2, 12);

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('root_a', 1, 12),
    ('root_b', 2, 12),
    ('heart', 3, 12);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_12_intro', 1, 12),
    ('wave_1', 'SecondsGte', 20, NULL::text, NULL::text, NULL::text, 2, 12),
    ('wave_2', 'SecondsGte', 45, NULL::text, NULL::text, NULL::text, 3, 12),
    ('wave_3', 'SecondsGte', 70, NULL::text, NULL::text, NULL::text, 4, 12),
    ('root_a_dead', 'InstallerDestroyed', 0, 'root_a', NULL::text, 'pve_12_root_a_dead', 5, 12),
    ('root_b_dead', 'InstallerDestroyed', 0, 'root_b', NULL::text, NULL::text, 6, 12);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'Vines hold the keep together. Tear out the roots.'),
    ('root_a_dead', 'Something stirs at the heart of the keep...')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 12;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp
FROM (VALUES
    ('intro', 1, 'SetSpawner', 'root_a', NULL::text, 0, NULL::real, NULL::integer, NULL::integer, NULL::integer),
    ('intro', 2, 'SetSpawner', 'root_b', NULL::text, 0, NULL::real, NULL::integer, NULL::integer, NULL::integer),
    ('wave_1', 1, 'SpawnWave', NULL::text, 'VineSpirit', 3, NULL::real, 14, 5, NULL::integer),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'FireChildSpirit', 5, NULL::real, 14, 3, NULL::integer),
    ('wave_3', 1, 'SpawnWave', NULL::text, 'VineSpirit', 3, NULL::real, 14, 7, NULL::integer),
    ('wave_3', 2, 'SpawnWave', NULL::text, 'EmberSpirit', 5, NULL::real, 14, 5, NULL::integer),
    ('root_a_dead', 1, 'InstallObject', 'heart', 'PveWaterSlimeNest', NULL::integer, NULL::real, 14, 5, 1550),
    ('root_a_dead', 2, 'SpawnWave', NULL::text, 'WaterSlime', 6, NULL::real, 14, 5, NULL::integer),
    ('root_b_dead', 1, 'SpawnWave', NULL::text, 'FireSpirit', 2, NULL::real, 14, 5, NULL::integer)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 12;

-- ---- scenario 13 (stage 4) ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('witch', 'PveVineWitch', 'RightPlayer', 14, 0, 5, 3250, 1, 13),
    ('guard_a', 'GroundCannon', 'RightPlayer', 14, 0, 3, 650, 2, 13),
    ('guard_b', 'GroundCannon', 'RightPlayer', 14, 0, 7, 650, 3, 13);

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('witch', 1, 13);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, 'witch', 'pve_13_intro', 1, 13),
    ('wave_1', 'SecondsGte', 40, NULL::text, NULL::text, NULL::text, 2, 13),
    ('wave_2', 'SecondsGte', 70, NULL::text, NULL::text, NULL::text, 3, 13),
    ('phase_70', 'InstallerHpPercentLte', 70, 'witch', 'witch', 'pve_13_phase_70', 4, 13),
    ('phase_40', 'InstallerHpPercentLte', 40, 'witch', 'witch', 'pve_13_phase_40', 5, 13),
    ('phase_15', 'InstallerHpPercentLte', 15, 'witch', 'witch', 'pve_13_phase_15', 6, 13);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'You again? My fortress will be your grave.'),
    ('phase_70', 'Forge spirits, burn them!'),
    ('phase_40', 'Stone, rise!'),
    ('phase_15', 'No... NO!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 13;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp
FROM (VALUES
    ('intro', 1, 'SetSpawner', 'witch', 'EmberSpirit', 5, 10, NULL::integer, NULL::integer, NULL::integer),
    ('wave_1', 1, 'SpawnWave', NULL::text, 'MiniRock', 3, NULL::real, 14, 3, NULL::integer),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'MiniRock', 3, NULL::real, 14, 7, NULL::integer),
    ('phase_70', 1, 'SpawnWave', NULL::text, 'FireSpirit', 2, NULL::real, 14, 3, NULL::integer),
    ('phase_70', 2, 'SetSpawner', 'witch', 'MiniRock', 3, 12, NULL::integer, NULL::integer, NULL::integer),
    ('phase_40', 1, 'InstallObject', 'guard_c', 'GroundCannon', NULL::integer, NULL::real, 14, 5, 650),
    ('phase_40', 2, 'SpawnWave', NULL::text, 'RockMage', 2, NULL::real, 14, 7, NULL::integer),
    ('phase_15', 1, 'SetSpawner', 'witch', NULL::text, 0, NULL::real, NULL::integer, NULL::integer, NULL::integer),
    ('phase_15', 2, 'SpawnWave', NULL::text, 'FireSpirit', 2, NULL::real, 14, 3, NULL::integer),
    ('phase_15', 3, 'SpawnWave', NULL::text, 'FireSpirit', 2, NULL::real, 14, 7, NULL::integer),
    ('phase_15', 4, 'SpawnWave', NULL::text, 'EmberSpirit', 8, NULL::real, 14, 5, NULL::integer)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 13;

-- 3. Rewards: one stage_clear_pc quest per new stage. require_value is the global count of
-- cleared stages once this migration lands (existing stage 1, plus stages 2, 3, 4).
-- Magic ids chosen against the test-env clone: none of 16 (life_tree, Nature), 83
-- (boulder_strike, Rock), 44 (meteor_shower, Fire) appear in reward_params, and none names a
-- prefab used as an enemy in this migration (unlike tree_golem/vine_spirit/vine_colony,
-- already spent on quests 5-8, or rock_mage/mini_rock/ember_spirit, which are fortress enemies).
INSERT INTO quests (id, progress_checker, require_value, reward_giver, access_type) VALUES
    (9, 'stage_clear_pc', 2, 'magic_rg', 'DEFAULT'),
    (10, 'stage_clear_pc', 3, 'magic_rg', 'DEFAULT'),
    (11, 'stage_clear_pc', 4, 'magic_rg', 'DEFAULT');

INSERT INTO reward_params (quest_id, name, value) VALUES
    (9, 'magic_id', 16),
    (10, 'magic_id', 83),
    (11, 'magic_id', 44);

-- 4. Sequences for every table this migration inserted into.
SELECT setval('adventures_id_seq', (SELECT max(id) FROM adventures));
SELECT setval('stages_id_seq', (SELECT max(id) FROM stages));
SELECT setval('scenarios_id_seq', (SELECT max(id) FROM scenarios));
SELECT setval('pve_scenario_installers_id_seq', (SELECT max(id) FROM pve_scenario_installers));
SELECT setval('pve_scenario_objectives_id_seq', (SELECT max(id) FROM pve_scenario_objectives));
SELECT setval('pve_scenario_events_id_seq', (SELECT max(id) FROM pve_scenario_events));
SELECT setval('pve_scenario_event_lines_id_seq', (SELECT max(id) FROM pve_scenario_event_lines));
SELECT setval('pve_scenario_event_actions_id_seq', (SELECT max(id) FROM pve_scenario_event_actions));
SELECT setval('quests_id_seq', (SELECT max(id) FROM quests));
SELECT setval('reward_params_id_seq', (SELECT max(id) FROM reward_params));


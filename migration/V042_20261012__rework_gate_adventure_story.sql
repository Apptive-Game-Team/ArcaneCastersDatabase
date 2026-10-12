-- V042: reworks the story of gate adventure stage 5 and 6 (scenarios 14-18) and adds the
-- PullPlayerUnits action and two corrupted spirit prefabs.
--
-- Story: hellspawn flood the village (14, hold out), a dimensional gate opens mid-match (15),
-- the great gate sends corrupted vine spirits (16), three gates send corrupted wind spirits (17),
-- and when the last rift breaks the evil ent appears, drags every summon of the player to itself
-- and the boss music starts (18). Scenario ids and stage ids are kept, so player progress survives.
--
--   id  stage  new element                          win                         structures (hp)                          phases
--   14  5      hold out, gate not visible           Survive 90 s                none                                      none
--   15  5      gate opens at 25 s                   gate_a                      gate_a toad 900 (InstallObject at 25 s)   none
--   16  5      corrupted vine spirit                great_gate                  great_gate toad 2200                      60 % SetSpawner + line, 30 % wave + line
--   17  6      corrupted wind spirit (air)          gate_a, gate_b, gate_c      three toads 800 each, no evil ent         none
--   18  6      evil ent, PullPlayerUnits, boss BGM  corrupted (installed later) rift toad 1600 -> corrupted evil ent 3000   rift 85/70/55/40/25 % waves; ent 60 % SetSpawner + wave, 30 % two gates + shield
--
-- Scenario 18: rift_dead installs corrupted (PveEvilEnt, 3000 hp), then PullPlayerUnits to
-- corrupted, then PlayBgm boss. Every wave before it is triggered by time before 30 s or by rift
-- hp, and nothing is timed after, so the 12 s after the ent appears have no wave (the player's
-- mana refills after losing the summons). The PlayBgm boss rows V041 put on the intro of
-- scenarios 17 and 18 are deleted with the old events; 17 has no boss now.
--
-- Pressure (value of the waves per 30 s / 120 mana, tadpole 5, corrupted vine spirit 7.5,
-- corrupted wind spirit 10, and each toad adding 1 tadpole per 10 s):
--   14  0.46  0.67  0.58          (first scenario, band 0.45-0.75)
--   15  0.88  0.88  0.96          (middle, band 0.75-1.2)
--   16  0.67  1.27  1.38          (last of stage 5, band 1.2-1.5); hp phases add 35 and 35 mana
--   17  0.92  1.12  1.19          (middle)
--   18  0.67 in 0-30 s, then about 1.2 per 30 s while the rift stands; waves are hp triggered
--       and so are not timed; the ent phases add a spawner of 2 corrupted vine spirits per 10 s
--
-- Unit values: pve_corrupted_vine_spirit is vine_spirit with hp 50, damage 14, attack_interval 1.0
-- and attack_range 1.5 (melee), about 1.5 tadpoles (pve_fire_tadpole is hp 30, damage 12 per
-- second). pve_corrupted_wind_spirit is wind_spirit with hp 50, damage 30, attack_interval 1.5 and
-- speed 1.2 (an air self-destruct unit), about 2 tadpoles. Every other key of the source rows is copied in SQL, so the live
-- values are used; magic_id, mana_cost and quantity are not copied (not cards). The numbers are
-- first guesses to be tuned by playing. vine_spirit and wind_spirit are not changed.
--
-- Message keys (the client adds them to the Adventure table, English and Korean):
--   pve_14_intro  Hellspawn are swarming the village! I will hold them off. Everyone, run!
--   pve_14_hold  There are so many of them. I cannot let them through!
--   pve_14_last  The villagers are almost clear. Hold on a little longer!
--   pve_15_intro  More of them! Where are they all coming from?
--   pve_15_gate_open  There! A dimensional gate is tearing open. Break it!
--   pve_15_keep_on  Keep hitting it. The tadpoles are coming out of that gate!
--   pve_16_intro  That is the great gate. It is pouring out something worse than tadpoles.
--   pve_16_phase_60  The gate twists the spirits as they pass through!
--   pve_16_phase_30  It is tearing itself open. Finish it!
--   pve_17_intro  Three gates, side by side. Close every one of them!
--   pve_17_air  Spirits are flying in over the walls. Watch the sky!
--   pve_17_gate_a_dead  One gate is closed!
--   pve_17_gate_b_dead  Another gate is closed!
--   pve_17_gate_c_dead  Another gate is closed!
--   pve_18_intro  That rift is where it all comes from. Break it!
--   pve_18_rift_half  The rift is cracking. Keep hitting it!
--   pve_18_rift_dead  The ancient ent! It is dragging my summons away!
--   pve_18_phase_60  The ent calls its spirits to its side!
--   pve_18_phase_30  Two more gates tear open to shield it!
--
-- Deploy order (all three together, database first):
--   * the game server with PullPlayerUnits, PveCorruptedVineSpirit and PveCorruptedWindSpirit
--     must deploy with this migration; an old server fails on the PullPlayerUnits row of
--     scenario 18 and on the new prefab types;
--   * scenario 14 is Survive with zero installer rows and zero objectives (the game server
--     loads that since ArcaneCastersGame#134). Scenario 15 is DestroyObjectives, which still
--     needs one installer, so it has an off-screen marker (PveDimensionToad at x=16, hp 99999,
--     not an objective) whose spawner event marker_quiet switches off at once.
-- Idempotent: constraint dropped before it is added, game_objects and parameter_values use ON
-- CONFLICT, and scenario 14-18 content is deleted before it is inserted again.
-- no-tags: the PVE prefabs are enemy-only and never enter a bot deck, so counter tags do not apply.

-- 1. PullPlayerUnits joins the action_type list.
ALTER TABLE "public"."pve_scenario_event_actions"
    DROP CONSTRAINT IF EXISTS "chk_pve_scenario_event_actions_action_type";

ALTER TABLE "public"."pve_scenario_event_actions"
    ADD CONSTRAINT "chk_pve_scenario_event_actions_action_type"
    CHECK ("action_type" IN ('SpawnWave', 'InstallObject', 'SetSpawner', 'PlayBgm', 'PullPlayerUnits'));

COMMENT ON COLUMN pve_scenario_event_actions.action_type IS
    'SpawnWave (spawn count objects of prefab_type at position_x/position_z), InstallObject (install a new object registered under installer_id, max_hp overrides its hp), SetSpawner (replace the periodic Spawner on installer_id; count = 0 removes it), PlayBgm (switch the background music to the track named by bgm_key; a null bgm_key returns to the scene default track), or PullPlayerUnits (drag every living mobile unit of the left player toward the object registered under installer_id for about 1.5 s, then destroy them; the player master and buildings are untouched).';

-- 2. Parameters of the two corrupted spirits.
INSERT INTO game_objects(name)
VALUES ('pve_corrupted_vine_spirit'), ('pve_corrupted_wind_spirit')
ON CONFLICT (name) DO NOTHING;

WITH copy_sources(object_name, source_name) AS (
    VALUES
        ('pve_corrupted_vine_spirit', 'vine_spirit'),
        ('pve_corrupted_wind_spirit', 'wind_spirit')
),
copied AS (
    SELECT cs.object_name, p.id AS parameter_id, pv.value
    FROM copy_sources cs
    JOIN game_objects src ON src.name = cs.source_name
    JOIN parameter_values pv ON pv.game_object_id = src.id
    JOIN parameters p ON p.id = pv.parameter_id
    WHERE p.name NOT IN ('magic_id', 'mana_cost', 'quantity')
),
overrides(object_name, parameter_name, value) AS (
    VALUES
        ('pve_corrupted_vine_spirit', 'hp', 50.0),
        ('pve_corrupted_vine_spirit', 'speed', 0.5),
        ('pve_corrupted_vine_spirit', 'damage', 14.0),
        ('pve_corrupted_vine_spirit', 'attack_interval', 1.0),
        ('pve_corrupted_vine_spirit', 'mass', 2.0),
        ('pve_corrupted_vine_spirit', 'radius', 0.8),
        ('pve_corrupted_vine_spirit', 'attack_range', 1.5),
        ('pve_corrupted_wind_spirit', 'hp', 50.0),
        ('pve_corrupted_wind_spirit', 'speed', 1.2),
        ('pve_corrupted_wind_spirit', 'damage', 30.0),
        ('pve_corrupted_wind_spirit', 'attack_interval', 1.5),
        ('pve_corrupted_wind_spirit', 'attack_range', 1.5),
        ('pve_corrupted_wind_spirit', 'mass', 1.0),
        ('pve_corrupted_wind_spirit', 'radius', 0.3)
),
merged AS (
    SELECT c.object_name, c.parameter_id, c.value
    FROM copied c
    WHERE NOT EXISTS (
        SELECT 1 FROM overrides o
        JOIN parameters p ON p.name = o.parameter_name
        WHERE o.object_name = c.object_name AND p.id = c.parameter_id
    )
    UNION ALL
    SELECT o.object_name, p.id, o.value
    FROM overrides o
    JOIN parameters p ON p.name = o.parameter_name
)
INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT go.id, m.parameter_id, m.value
FROM merged m
JOIN game_objects go ON go.name = m.object_name
ON CONFLICT (parameter_id, game_object_id)
DO UPDATE SET value = EXCLUDED.value, updated_at = now();

INSERT INTO prefab_elements(prefab, element)
VALUES
    ('pve_corrupted_vine_spirit', 'Nature'),
    ('pve_corrupted_wind_spirit', 'Wind')
ON CONFLICT (prefab, element) DO NOTHING;

DO
$$
    DECLARE
        missing text;
    BEGIN
        SELECT string_agg(r.object_name || '.' || r.key, ', ') INTO missing
        FROM (VALUES
            ('pve_corrupted_vine_spirit', 'hp'), ('pve_corrupted_vine_spirit', 'speed'),
            ('pve_corrupted_vine_spirit', 'damage'), ('pve_corrupted_vine_spirit', 'attack_interval'),
            ('pve_corrupted_vine_spirit', 'mass'), ('pve_corrupted_vine_spirit', 'radius'),
            ('pve_corrupted_wind_spirit', 'hp'), ('pve_corrupted_wind_spirit', 'speed'),
            ('pve_corrupted_wind_spirit', 'damage'), ('pve_corrupted_wind_spirit', 'attack_interval'),
            ('pve_corrupted_wind_spirit', 'attack_range'), ('pve_corrupted_wind_spirit', 'mass'),
            ('pve_corrupted_wind_spirit', 'radius')
        ) AS r(object_name, key)
        WHERE NOT EXISTS (
            SELECT 1
            FROM parameter_values pv
            JOIN game_objects go ON go.id = pv.game_object_id
            JOIN parameters p ON p.id = pv.parameter_id
            WHERE go.name = r.object_name AND p.name = r.key
        );
        IF missing IS NOT NULL THEN
            RAISE EXCEPTION 'missing parameter rows: %', missing;
        END IF;
    END
$$;

-- 3. Scenarios 14-18 start empty. pve_scenario_events cascades to lines and actions.
DELETE FROM pve_scenario_events WHERE scenario_id IN (14, 15, 16, 17, 18);
DELETE FROM pve_scenario_objectives WHERE scenario_id IN (14, 15, 16, 17, 18);
DELETE FROM pve_scenario_rules WHERE scenario_id IN (14, 15, 16, 17, 18);
DELETE FROM pve_scenario_shields WHERE scenario_id IN (14, 15, 16, 17, 18);
DELETE FROM pve_scenario_installers WHERE scenario_id IN (14, 15, 16, 17, 18);

-- ---- scenario 14: Survive 90 s, no gate, no installer ----
INSERT INTO pve_scenario_rules (scenario_id, win_condition, survive_seconds) VALUES
    (14, 'Survive', 90);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_14_intro', 1, 14),
    ('wave_1', 'SecondsGte', 8, NULL::text, NULL::text, NULL::text, 2, 14),
    ('wave_2', 'SecondsGte', 17, NULL::text, NULL::text, NULL::text, 3, 14),
    ('wave_3', 'SecondsGte', 23, NULL::text, NULL::text, NULL::text, 4, 14),
    ('wave_4', 'SecondsGte', 29, NULL::text, NULL::text, NULL::text, 5, 14),
    ('wave_5', 'SecondsGte', 34, NULL::text, NULL::text, NULL::text, 6, 14),
    ('wave_6', 'SecondsGte', 40, NULL::text, NULL::text, NULL::text, 7, 14),
    ('wave_7', 'SecondsGte', 46, NULL::text, NULL::text, NULL::text, 8, 14),
    ('wave_8', 'SecondsGte', 52, NULL::text, NULL::text, NULL::text, 9, 14),
    ('wave_9', 'SecondsGte', 58, NULL::text, NULL::text, NULL::text, 10, 14),
    ('wave_10', 'SecondsGte', 64, NULL::text, NULL::text, NULL::text, 11, 14),
    ('wave_11', 'SecondsGte', 70, NULL::text, NULL::text, NULL::text, 12, 14),
    ('wave_12', 'SecondsGte', 76, NULL::text, NULL::text, NULL::text, 13, 14),
    ('wave_13', 'SecondsGte', 82, NULL::text, NULL::text, NULL::text, 14, 14),
    ('hold', 'SecondsGte', 36, NULL::text, NULL::text, 'pve_14_hold', 15, 14),
    ('last', 'SecondsGte', 72, NULL::text, NULL::text, 'pve_14_last', 16, 14);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'Hellspawn are swarming the village! I will hold them off. Everyone, run!'),
    ('hold', 'There are so many of them. I cannot let them through!'),
    ('last', 'The villagers are almost clear. Hold on a little longer!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 14;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp, bgm_key)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp, v.bgm_key
FROM (VALUES
    ('wave_1', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 2, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 3, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_3', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 3, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('wave_4', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 3, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('wave_5', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 3, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_6', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 3, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('wave_7', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 4, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('wave_8', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 3, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_9', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 3, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('wave_10', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 4, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('wave_11', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 3, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_12', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 4, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('wave_13', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 3, NULL::real, 14, 5, NULL::integer, NULL::text)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp, bgm_key)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 14;

-- ---- scenario 15: gate_a opens at 25 s ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('marker', 'PveDimensionToad', 'RightPlayer', 16, 0, 5, 99999, 1, 15);

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('gate_a', 1, 15);

INSERT INTO pve_scenario_rules (scenario_id, win_condition, survive_seconds) VALUES
    (15, 'DestroyObjectives', NULL::integer);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('marker_quiet', 'SecondsGte', 0, NULL::text, NULL::text, NULL::text, 1, 15),
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_15_intro', 2, 15),
    ('wave_1', 'SecondsGte', 8, NULL::text, NULL::text, NULL::text, 3, 15),
    ('wave_2', 'SecondsGte', 17, NULL::text, NULL::text, NULL::text, 4, 15),
    ('wave_3', 'SecondsGte', 21, NULL::text, NULL::text, NULL::text, 5, 15),
    ('wave_4', 'SecondsGte', 28, NULL::text, NULL::text, NULL::text, 6, 15),
    ('gate_open', 'SecondsGte', 25, NULL::text, NULL::text, 'pve_15_gate_open', 7, 15),
    ('wave_5', 'SecondsGte', 34, NULL::text, NULL::text, NULL::text, 8, 15),
    ('wave_6', 'SecondsGte', 40, NULL::text, NULL::text, NULL::text, 9, 15),
    ('wave_7', 'SecondsGte', 47, NULL::text, NULL::text, NULL::text, 10, 15),
    ('wave_8', 'SecondsGte', 54, NULL::text, NULL::text, NULL::text, 11, 15),
    ('wave_9', 'SecondsGte', 62, NULL::text, NULL::text, NULL::text, 12, 15),
    ('wave_10', 'SecondsGte', 69, NULL::text, NULL::text, NULL::text, 13, 15),
    ('wave_11', 'SecondsGte', 76, NULL::text, NULL::text, NULL::text, 14, 15),
    ('wave_12', 'SecondsGte', 83, NULL::text, NULL::text, NULL::text, 15, 15),
    ('keep_on', 'SecondsGte', 60, NULL::text, NULL::text, 'pve_15_keep_on', 16, 15);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'More of them! Where are they all coming from?'),
    ('gate_open', 'There! A dimensional gate is tearing open. Break it!'),
    ('keep_on', 'Keep hitting it. The tadpoles are coming out of that gate!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 15;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp, bgm_key)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp, v.bgm_key
FROM (VALUES
    ('marker_quiet', 1, 'SetSpawner', 'marker', NULL::text, 0, NULL::real, NULL::integer, NULL::integer, NULL::integer, NULL::text),
    ('wave_1', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 3, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 4, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_3', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 5, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('wave_4', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 5, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('gate_open', 1, 'InstallObject', 'gate_a', 'PveDimensionToad', NULL::integer, NULL::real, 14, 5, 900, NULL::text),
    ('wave_5', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 4, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_6', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 4, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('wave_7', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 5, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('wave_8', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 5, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_9', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 5, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('wave_10', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 5, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_11', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 5, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('wave_12', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 5, NULL::real, 14, 7, NULL::integer, NULL::text)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp, bgm_key)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 15;

-- ---- scenario 16: great_gate, corrupted vine spirit ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('great_gate', 'PveDimensionToad', 'RightPlayer', 14, 0, 5, 2200, 1, 16);

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('great_gate', 1, 16);

INSERT INTO pve_scenario_rules (scenario_id, win_condition, survive_seconds) VALUES
    (16, 'DestroyObjectives', NULL::integer);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_16_intro', 1, 16),
    ('wave_1', 'SecondsGte', 8, NULL::text, NULL::text, NULL::text, 2, 16),
    ('wave_2', 'SecondsGte', 17, NULL::text, NULL::text, NULL::text, 3, 16),
    ('wave_3', 'SecondsGte', 25, NULL::text, NULL::text, NULL::text, 4, 16),
    ('wave_4', 'SecondsGte', 30, NULL::text, NULL::text, NULL::text, 5, 16),
    ('wave_5', 'SecondsGte', 36, NULL::text, NULL::text, NULL::text, 6, 16),
    ('wave_6', 'SecondsGte', 42, NULL::text, NULL::text, NULL::text, 7, 16),
    ('wave_7', 'SecondsGte', 49, NULL::text, NULL::text, NULL::text, 8, 16),
    ('wave_8', 'SecondsGte', 56, NULL::text, NULL::text, NULL::text, 9, 16),
    ('wave_9', 'SecondsGte', 64, NULL::text, NULL::text, NULL::text, 10, 16),
    ('wave_10', 'SecondsGte', 70, NULL::text, NULL::text, NULL::text, 11, 16),
    ('wave_11', 'SecondsGte', 77, NULL::text, NULL::text, NULL::text, 12, 16),
    ('wave_12', 'SecondsGte', 84, NULL::text, NULL::text, NULL::text, 13, 16),
    ('phase_60', 'InstallerHpPercentLte', 60, 'great_gate', 'great_gate', 'pve_16_phase_60', 14, 16),
    ('phase_30', 'InstallerHpPercentLte', 30, 'great_gate', 'great_gate', 'pve_16_phase_30', 15, 16);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'That is the great gate. It is pouring out something worse than tadpoles.'),
    ('phase_60', 'The gate twists the spirits as they pass through!'),
    ('phase_30', 'It is tearing itself open. Finish it!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 16;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp, bgm_key)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp, v.bgm_key
FROM (VALUES
    ('wave_1', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 3, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 4, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('wave_3', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 5, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('wave_4', 1, 'SpawnWave', NULL::text, 'PveCorruptedVineSpirit', 2, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_5', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 5, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('wave_5', 2, 'SpawnWave', NULL::text, 'PveFireTadpole', 2, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_6', 1, 'SpawnWave', NULL::text, 'PveCorruptedVineSpirit', 3, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('wave_7', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 4, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_7', 2, 'SpawnWave', NULL::text, 'PveCorruptedVineSpirit', 2, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('wave_8', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 6, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('wave_9', 1, 'SpawnWave', NULL::text, 'PveCorruptedVineSpirit', 3, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('wave_9', 2, 'SpawnWave', NULL::text, 'PveLightningTadpole', 4, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_10', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 7, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('wave_11', 1, 'SpawnWave', NULL::text, 'PveCorruptedVineSpirit', 5, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_12', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 7, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('phase_60', 1, 'SetSpawner', 'great_gate', 'PveCorruptedVineSpirit', 1, 10, NULL::integer, NULL::integer, NULL::integer, NULL::text),
    ('phase_30', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 4, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('phase_30', 2, 'SpawnWave', NULL::text, 'PveCorruptedVineSpirit', 2, NULL::real, 14, 7, NULL::integer, NULL::text)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp, bgm_key)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 16;

-- ---- scenario 17: three gates, corrupted wind spirit ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('gate_a', 'PveDimensionToad', 'RightPlayer', 14, 0, 3, 800, 1, 17),
    ('gate_b', 'PveDimensionToad', 'RightPlayer', 14, 0, 5, 800, 2, 17),
    ('gate_c', 'PveDimensionToad', 'RightPlayer', 14, 0, 7, 800, 3, 17);

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('gate_a', 1, 17),
    ('gate_b', 2, 17),
    ('gate_c', 3, 17);

INSERT INTO pve_scenario_rules (scenario_id, win_condition, survive_seconds) VALUES
    (17, 'DestroyObjectives', NULL::integer);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_17_intro', 1, 17),
    ('wave_1', 'SecondsGte', 8, NULL::text, NULL::text, NULL::text, 2, 17),
    ('wave_2', 'SecondsGte', 18, NULL::text, NULL::text, NULL::text, 3, 17),
    ('air', 'SecondsGte', 22, NULL::text, NULL::text, 'pve_17_air', 4, 17),
    ('wave_3', 'SecondsGte', 26, NULL::text, NULL::text, NULL::text, 5, 17),
    ('wave_4', 'SecondsGte', 32, NULL::text, NULL::text, NULL::text, 6, 17),
    ('wave_5', 'SecondsGte', 40, NULL::text, NULL::text, NULL::text, 7, 17),
    ('wave_6', 'SecondsGte', 47, NULL::text, NULL::text, NULL::text, 8, 17),
    ('wave_7', 'SecondsGte', 54, NULL::text, NULL::text, NULL::text, 9, 17),
    ('wave_8', 'SecondsGte', 62, NULL::text, NULL::text, NULL::text, 10, 17),
    ('wave_9', 'SecondsGte', 70, NULL::text, NULL::text, NULL::text, 11, 17),
    ('wave_10', 'SecondsGte', 77, NULL::text, NULL::text, NULL::text, 12, 17),
    ('wave_11', 'SecondsGte', 84, NULL::text, NULL::text, NULL::text, 13, 17),
    ('gate_a_dead', 'InstallerDestroyed', 0, 'gate_a', NULL::text, 'pve_17_gate_a_dead', 14, 17),
    ('gate_b_dead', 'InstallerDestroyed', 0, 'gate_b', NULL::text, 'pve_17_gate_b_dead', 15, 17),
    ('gate_c_dead', 'InstallerDestroyed', 0, 'gate_c', NULL::text, 'pve_17_gate_c_dead', 16, 17);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'Three gates, side by side. Close every one of them!'),
    ('air', 'Spirits are flying in over the walls. Watch the sky!'),
    ('gate_a_dead', 'One gate is closed!'),
    ('gate_b_dead', 'Another gate is closed!'),
    ('gate_c_dead', 'Another gate is closed!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 17;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp, bgm_key)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp, v.bgm_key
FROM (VALUES
    ('wave_1', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 3, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'PveCorruptedWindSpirit', 2, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('wave_3', 1, 'SpawnWave', NULL::text, 'PveCorruptedVineSpirit', 2, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_4', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 3, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('wave_4', 2, 'SpawnWave', NULL::text, 'PveCorruptedWindSpirit', 1, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_5', 1, 'SpawnWave', NULL::text, 'PveCorruptedVineSpirit', 3, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('wave_6', 1, 'SpawnWave', NULL::text, 'PveCorruptedWindSpirit', 2, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('wave_7', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 3, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_7', 2, 'SpawnWave', NULL::text, 'PveCorruptedVineSpirit', 1, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('wave_8', 1, 'SpawnWave', NULL::text, 'PveCorruptedWindSpirit', 2, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('wave_8', 2, 'SpawnWave', NULL::text, 'PveCorruptedVineSpirit', 1, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_9', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 4, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('wave_10', 1, 'SpawnWave', NULL::text, 'PveCorruptedWindSpirit', 2, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_11', 1, 'SpawnWave', NULL::text, 'PveCorruptedVineSpirit', 2, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('wave_11', 2, 'SpawnWave', NULL::text, 'PveFireTadpole', 3, NULL::real, 14, 5, NULL::integer, NULL::text)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp, bgm_key)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 17;

-- ---- scenario 18: rift, then the evil ent ----
INSERT INTO pve_scenario_installers
    (installer_id, prefab_type, master, position_x, position_y, position_z, max_hp, sort_order, scenario_id)
VALUES
    ('rift', 'PveDimensionToad', 'RightPlayer', 14, 0, 5, 1600, 1, 18);

INSERT INTO pve_scenario_shields (scenario_id, installer_id, source_installer_id) VALUES
    (18, 'corrupted', 'gate_c'),
    (18, 'corrupted', 'gate_d');

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id) VALUES
    ('corrupted', 1, 18);

INSERT INTO pve_scenario_rules (scenario_id, win_condition, survive_seconds) VALUES
    (18, 'DestroyObjectives', NULL::integer);

INSERT INTO pve_scenario_events
    (event_id, trigger_type, trigger_value, target_installer_id, speaker_installer_id, message_key, sort_order, scenario_id)
VALUES
    ('intro', 'SecondsGte', 1, NULL::text, NULL::text, 'pve_18_intro', 1, 18),
    ('wave_1', 'SecondsGte', 8, NULL::text, NULL::text, NULL::text, 2, 18),
    ('wave_2', 'SecondsGte', 17, NULL::text, NULL::text, NULL::text, 3, 18),
    ('wave_3', 'SecondsGte', 26, NULL::text, NULL::text, NULL::text, 4, 18),
    ('rift_85', 'InstallerHpPercentLte', 85, 'rift', NULL::text, NULL::text, 5, 18),
    ('rift_70', 'InstallerHpPercentLte', 70, 'rift', NULL::text, NULL::text, 6, 18),
    ('rift_half', 'InstallerHpPercentLte', 55, 'rift', 'rift', 'pve_18_rift_half', 7, 18),
    ('rift_40', 'InstallerHpPercentLte', 40, 'rift', NULL::text, NULL::text, 8, 18),
    ('rift_25', 'InstallerHpPercentLte', 25, 'rift', NULL::text, NULL::text, 9, 18),
    ('rift_dead', 'InstallerDestroyed', 0, 'rift', NULL::text, 'pve_18_rift_dead', 10, 18),
    ('phase_60', 'InstallerHpPercentLte', 60, 'corrupted', 'corrupted', 'pve_18_phase_60', 11, 18),
    ('phase_30', 'InstallerHpPercentLte', 30, 'corrupted', 'corrupted', 'pve_18_phase_30', 12, 18);

INSERT INTO pve_scenario_event_lines (event_row_id, line_order, line_text)
SELECT e.id, 1, v.line_text
FROM (VALUES
    ('intro', 'That rift is where it all comes from. Break it!'),
    ('rift_half', 'The rift is cracking. Keep hitting it!'),
    ('rift_dead', 'The ancient ent! It is dragging my summons away!'),
    ('phase_60', 'The ent calls its spirits to its side!'),
    ('phase_30', 'Two more gates tear open to shield it!')
) AS v(event_id, line_text)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 18;

INSERT INTO pve_scenario_event_actions
    (event_row_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds, position_x, position_z, max_hp, bgm_key)
SELECT e.id, v.action_order, v.action_type, v.installer_id, v.prefab_type, v.count, v.interval_seconds,
       v.position_x, v.position_z, v.max_hp, v.bgm_key
FROM (VALUES
    ('wave_1', 1, 'SpawnWave', NULL::text, 'PveFireTadpole', 3, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('wave_2', 1, 'SpawnWave', NULL::text, 'PveCorruptedVineSpirit', 2, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('wave_3', 1, 'SpawnWave', NULL::text, 'PveCorruptedWindSpirit', 3, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('rift_85', 1, 'SpawnWave', NULL::text, 'PveLightningTadpole', 5, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('rift_85', 2, 'SpawnWave', NULL::text, 'PveCorruptedVineSpirit', 2, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('rift_70', 1, 'SpawnWave', NULL::text, 'PveCorruptedWindSpirit', 3, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('rift_70', 2, 'SpawnWave', NULL::text, 'PveFireTadpole', 4, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('rift_half', 1, 'SpawnWave', NULL::text, 'PveCorruptedVineSpirit', 3, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('rift_half', 2, 'SpawnWave', NULL::text, 'PveLightningTadpole', 4, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('rift_40', 1, 'SpawnWave', NULL::text, 'PveCorruptedWindSpirit', 3, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('rift_40', 2, 'SpawnWave', NULL::text, 'PveFireTadpole', 4, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('rift_25', 1, 'SpawnWave', NULL::text, 'PveCorruptedVineSpirit', 3, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('rift_25', 2, 'SpawnWave', NULL::text, 'PveCorruptedWindSpirit', 2, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('rift_dead', 1, 'InstallObject', 'corrupted', 'PveEvilEnt', NULL::integer, NULL::real, 14, 5, 3000, NULL::text),
    ('rift_dead', 2, 'PullPlayerUnits', 'corrupted', NULL::text, NULL::integer, NULL::real, NULL::integer, NULL::integer, NULL::integer, NULL::text),
    ('rift_dead', 3, 'PlayBgm', NULL::text, NULL::text, NULL::integer, NULL::real, NULL::integer, NULL::integer, NULL::integer, 'boss'),
    ('phase_60', 1, 'SetSpawner', 'corrupted', 'PveCorruptedVineSpirit', 2, 10, NULL::integer, NULL::integer, NULL::integer, NULL::text),
    ('phase_60', 2, 'SpawnWave', NULL::text, 'PveCorruptedWindSpirit', 3, NULL::real, 14, 3, NULL::integer, NULL::text),
    ('phase_60', 3, 'SpawnWave', NULL::text, 'PveCorruptedVineSpirit', 2, NULL::real, 14, 7, NULL::integer, NULL::text),
    ('phase_30', 1, 'InstallObject', 'gate_c', 'PveDimensionToad', NULL::integer, NULL::real, 14, 3, 500, NULL::text),
    ('phase_30', 2, 'InstallObject', 'gate_d', 'PveDimensionToad', NULL::integer, NULL::real, 14, 7, 500, NULL::text),
    ('phase_30', 3, 'SpawnWave', NULL::text, 'PveCorruptedWindSpirit', 3, NULL::real, 14, 5, NULL::integer, NULL::text),
    ('phase_30', 4, 'SpawnWave', NULL::text, 'PveLightningTadpole', 4, NULL::real, 14, 7, NULL::integer, NULL::text)
) AS v(event_id, action_order, action_type, installer_id, prefab_type, count, interval_seconds,
       position_x, position_z, max_hp, bgm_key)
JOIN pve_scenario_events e ON e.event_id = v.event_id AND e.scenario_id = 18;

-- 4. Sequences for every table this migration inserted into.
SELECT setval('game_objects_id_seq', (SELECT max(id) FROM game_objects));
SELECT setval('parameter_values_id_seq', (SELECT max(id) FROM parameter_values));
SELECT setval('pve_scenario_installers_id_seq', (SELECT max(id) FROM pve_scenario_installers));
SELECT setval('pve_scenario_objectives_id_seq', (SELECT max(id) FROM pve_scenario_objectives));
SELECT setval('pve_scenario_events_id_seq', (SELECT max(id) FROM pve_scenario_events));
SELECT setval('pve_scenario_event_lines_id_seq', (SELECT max(id) FROM pve_scenario_event_lines));
SELECT setval('pve_scenario_event_actions_id_seq', (SELECT max(id) FROM pve_scenario_event_actions));

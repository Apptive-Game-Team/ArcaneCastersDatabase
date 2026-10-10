--
-- V035: adds pve_scenario_event_actions.bgm_key and the PlayBgm action_type.
-- PlayBgm switches the background music of a PVE match to the track named by bgm_key. A null
-- bgm_key returns to the scene's default track. The column is null for every other action_type.
-- The action_type CHECK constraint (chk_pve_scenario_event_actions_action_type, V012) is
-- dropped and added again with PlayBgm in the list.
-- Idempotent: ADD COLUMN IF NOT EXISTS, and the constraint is dropped before it is added.
-- No pve_scenario_event_actions row is inserted or changed; existing rows keep bgm_key null.
-- no-tags: no game_objects or magics row is registered here.

ALTER TABLE "public"."pve_scenario_event_actions"
    ADD COLUMN IF NOT EXISTS "bgm_key" character varying(50);

ALTER TABLE "public"."pve_scenario_event_actions"
    DROP CONSTRAINT IF EXISTS "chk_pve_scenario_event_actions_action_type";

ALTER TABLE "public"."pve_scenario_event_actions"
    ADD CONSTRAINT "chk_pve_scenario_event_actions_action_type"
    CHECK ("action_type" IN ('SpawnWave', 'InstallObject', 'SetSpawner', 'PlayBgm'));

COMMENT ON TABLE pve_scenario_event_actions IS
    'Scripted actions a pve_scenario_events row runs, in action_order, after its dialogue is sent. Every object an action creates belongs to RightPlayer. PlayBgm creates no object; it changes the background music.';

COMMENT ON COLUMN pve_scenario_event_actions.action_type IS
    'SpawnWave (spawn count objects of prefab_type at position_x/position_z), InstallObject (install a new object registered under installer_id, max_hp overrides its hp), SetSpawner (replace the periodic Spawner on installer_id; count = 0 removes it), or PlayBgm (switch the background music to the track named by bgm_key; a null bgm_key returns to the scene default track).';

COMMENT ON COLUMN pve_scenario_event_actions.bgm_key IS
    'Background music track key a PlayBgm action switches to. Null on PlayBgm returns to the scene default track. Null for every other action_type.';

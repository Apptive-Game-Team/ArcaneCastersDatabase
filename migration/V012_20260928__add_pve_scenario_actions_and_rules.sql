-- PVE engine rework: installers can override boss hp per scenario, events can watch an
-- installer's hp or death instead of only elapsed frames, events can run scripted actions
-- (spawning waves, installing new objects, changing a spawner), and a scenario can declare
-- a Survive win condition instead of DestroyObjectives. Pairs with the game server PVE
-- engine pull request. No content rows here - content comes in V013.
-- no-tags: no game_objects or magics row is registered here.

ALTER TABLE pve_scenario_installers
    ADD COLUMN IF NOT EXISTS max_hp integer;

COMMENT ON COLUMN pve_scenario_installers.max_hp IS
    'Overrides the boss prefab''s parameter hp for this installer only. NULL keeps the prefab default, so the same boss prefab can be weaker in one stage and stronger in another.';

ALTER TABLE pve_scenario_events
    ADD COLUMN IF NOT EXISTS target_installer_id character varying(50);

COMMENT ON COLUMN pve_scenario_events.target_installer_id IS
    'The installer_id a trigger watches (InstallerHpPercentLte, InstallerDestroyed). Unused by FrameNumGte and SecondsGte.';

ALTER TABLE pve_scenario_events
    ALTER COLUMN message_key DROP NOT NULL;

COMMENT ON COLUMN pve_scenario_events.message_key IS
    'Dialogue key sent when this event fires. NULL means the event sends no dialogue - it only runs its actions.';

--
-- Name: pve_scenario_event_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS "public"."pve_scenario_event_actions" (
    "id" bigint NOT NULL,
    "event_row_id" bigint NOT NULL,
    "action_order" integer NOT NULL,
    "action_type" character varying(30) NOT NULL,
    "installer_id" character varying(50),
    "prefab_type" character varying(50),
    "count" integer,
    "interval_seconds" real,
    "position_x" integer,
    "position_z" integer,
    "max_hp" integer
);

COMMENT ON TABLE pve_scenario_event_actions IS
    'Scripted actions a pve_scenario_events row runs, in action_order, after its dialogue is sent. Every object an action creates belongs to RightPlayer.';

COMMENT ON COLUMN pve_scenario_event_actions.action_type IS
    'SpawnWave (spawn count objects of prefab_type at position_x/position_z), InstallObject (install a new object registered under installer_id, max_hp overrides its hp), or SetSpawner (replace the periodic Spawner on installer_id; count = 0 removes it).';

--
-- Name: pve_scenario_event_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE IF NOT EXISTS "public"."pve_scenario_event_actions_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: pve_scenario_event_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."pve_scenario_event_actions_id_seq" OWNED BY "public"."pve_scenario_event_actions"."id";

ALTER TABLE ONLY "public"."pve_scenario_event_actions"
    ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."pve_scenario_event_actions_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."pve_scenario_event_actions"
    DROP CONSTRAINT IF EXISTS "pve_scenario_event_actions_pkey";

ALTER TABLE ONLY "public"."pve_scenario_event_actions"
    ADD CONSTRAINT "pve_scenario_event_actions_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."pve_scenario_event_actions"
    DROP CONSTRAINT IF EXISTS "pve_scenario_event_actions_event_row_id_fkey";

ALTER TABLE ONLY "public"."pve_scenario_event_actions"
    ADD CONSTRAINT "pve_scenario_event_actions_event_row_id_fkey" FOREIGN KEY ("event_row_id") REFERENCES "public"."pve_scenario_events"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."pve_scenario_event_actions"
    DROP CONSTRAINT IF EXISTS "uq_pve_scenario_event_action_row_order";

ALTER TABLE ONLY "public"."pve_scenario_event_actions"
    ADD CONSTRAINT "uq_pve_scenario_event_action_row_order" UNIQUE ("event_row_id", "action_order");

ALTER TABLE "public"."pve_scenario_event_actions"
    DROP CONSTRAINT IF EXISTS "chk_pve_scenario_event_actions_action_type";

ALTER TABLE "public"."pve_scenario_event_actions"
    ADD CONSTRAINT "chk_pve_scenario_event_actions_action_type" CHECK ("action_type" IN ('SpawnWave', 'InstallObject', 'SetSpawner'));

--
-- Name: pve_scenario_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS "public"."pve_scenario_rules" (
    "scenario_id" bigint NOT NULL,
    "win_condition" character varying(30) DEFAULT 'DestroyObjectives' NOT NULL,
    "survive_seconds" integer
);

COMMENT ON TABLE pve_scenario_rules IS
    'One optional row per scenario. No row means DestroyObjectives, which is today''s behavior.';

COMMENT ON COLUMN pve_scenario_rules.win_condition IS
    'DestroyObjectives: every installer id in pve_scenario_objectives must be terminal. Survive: cleared once elapsed seconds >= survive_seconds while the player is alive; objectives are ignored.';

ALTER TABLE ONLY "public"."pve_scenario_rules"
    DROP CONSTRAINT IF EXISTS "pve_scenario_rules_pkey";

ALTER TABLE ONLY "public"."pve_scenario_rules"
    ADD CONSTRAINT "pve_scenario_rules_pkey" PRIMARY KEY ("scenario_id");

ALTER TABLE ONLY "public"."pve_scenario_rules"
    DROP CONSTRAINT IF EXISTS "pve_scenario_rules_scenario_id_fkey";

ALTER TABLE ONLY "public"."pve_scenario_rules"
    ADD CONSTRAINT "pve_scenario_rules_scenario_id_fkey" FOREIGN KEY ("scenario_id") REFERENCES "public"."scenarios"("id") ON DELETE CASCADE;

ALTER TABLE "public"."pve_scenario_rules"
    DROP CONSTRAINT IF EXISTS "chk_pve_scenario_rules_win_condition";

ALTER TABLE "public"."pve_scenario_rules"
    ADD CONSTRAINT "chk_pve_scenario_rules_win_condition" CHECK ("win_condition" IN ('DestroyObjectives', 'Survive'));

ALTER TABLE "public"."pve_scenario_rules"
    DROP CONSTRAINT IF EXISTS "chk_pve_scenario_rules_survive_seconds";

ALTER TABLE "public"."pve_scenario_rules"
    ADD CONSTRAINT "chk_pve_scenario_rules_survive_seconds" CHECK (
        ("win_condition" = 'Survive' AND "survive_seconds" IS NOT NULL)
        OR ("win_condition" <> 'Survive')
    );

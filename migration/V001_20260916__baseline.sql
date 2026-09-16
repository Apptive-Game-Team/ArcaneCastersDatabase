-- Baseline for the shared game database, replacing V000 through V119.
--
-- Applying this file to an empty PostgreSQL 14 database produces the schema at the tip of
-- `dev` (last migration V119_20260916__widen_dragon_tower_range_and_repair_totem_life.sql)
-- together with the game definition rows, minus the four card tables that the next section
-- drops and renames.
--
-- It was built by replaying that chain into an empty database and dumping the result, then
-- overlaying the values that live only in `wordonlinedev`. The schema is what the chain
-- produced; the sections below list every row that is not, and every object that is not.
--
-- ------------------------------------------ what this file changes against the chain tip
--
-- The chain tip still carries four tables from the card era. The game server reads a deck
-- as magic ids and writes them into statistic_game_cards.card_id, whose foreign key points
-- at cards(id). `cards` holds 11 rows with ids 1 through 11, so every magic outside that
-- range fails the insert. The starter deck is magma_explosion 19, leafair 24,
-- lightning_drop 35, rock_drop 54 and chicken_commando 55, and every player and every bot
-- starts with it, so the foreign key fails the first time any match ends.
--
--   Dropped: `cards` (11 rows), `magic_cards` (168 rows) and `user_cards` (empty), with
--   their sequences, indexes, constraints and the update_magic_cards_modtime trigger. The
--   game server's MagicRepository already records that magic_cards and cards are gone, and
--   the lobby's Card and UserCard classes map to `magics` and `user_magics`.
--
--   Renamed: `statistic_game_cards` to `statistic_game_decks`, its `card_id` column to
--   `magic_id`, its sequence to statistic_game_decks_id_seq and its index to
--   idx_statistic_game_deck_user_id_statistic_game_id. The foreign key now points at
--   magics(id); the one to statistic_games(id) ON DELETE CASCADE is unchanged. The table
--   records which deck a player brought to a match, which statistic_game_magics (how many
--   times each magic was cast) does not, so it survives. It is empty, so nothing migrates.
--
--   Kept: the `card_type` enum. Nothing uses it once `cards` is gone, and dropping an
--   otherwise harmless type is a separate decision.
--
-- ---------------------------------------------------------------------------- rows present
--
--   Game definition: magics, game_objects, prefab_elements, parameters, parameter_values,
--   deck_cards, tags, game_object_tags, magic_tags, tag_counter_rules, magic_parameters,
--   magic_game_object_aliases, adventures, stages, scenarios, the four pve_scenario_*
--   tables, quests, reward_params, decorations.
--
--   `users` carries the 58 bot rows only, at the ids wordonlinedev uses (-62 .. -1). Every
--   one is negative, which is the bot identity contract in README.md, and
--   `bot_personas.user_id` is a foreign key to `users.id`, so the bots cannot be registered
--   without them. `users_id_seq` is left unused and starts at 1, so regenerated real players
--   take positive ids and never meet the bot range. `decks`, `deck_cards` and `user_magics`
--   likewise hold bot-owned rows plus the starter deck template at `decks.user_id = 0`.
--
--   No real player data. `user_decorations`, `user_quests`, `user_scenarios`,
--   `statistic_games`, `statistic_game_decks`, `statistic_game_magics`,
--   `statistic_game_sessions`, `statistic_update_time`, `servers` and `deploy_status` are
--   created empty.
--
-- ------------------------------------------------------- what came from the live database
--
-- The migration chain is not the whole record. These rows were taken from `wordonlinedev`
-- because no migration produces them.
--
--   1. 23 parameter_values, hand-tuned through the admin server on nine dates between
--      2026-07-27 and 2026-09-14. The largest is `player` hp: V053 multiplied every hp and
--      damage by 10, V054 was ordered after it and inserted `player` hp as a literal 100,
--      and the live databases carry the hand-fixed 1000. A baseline built from the files
--      alone would give every player a tenth of their intended health.
--   2. magic_tags: meteor_shower carries CAT_AoE. The game object holds only TYPE_Data, so
--      sync_magic_tags_from_game_objects() cannot derive it. Without the tag the bot counter
--      evaluator scores meteor_shower 0.0 and never reasons about it.
--   3. tag_counter_rules: CAT_AoE against CAT_Small weighs 1, not the 2 the chain writes.
--   4. The 12 bots that predate the chain (ids -1 and -6 .. -16), which reached the live
--      databases through bot_personas_legacy_20260711. All 12 are `enabled = false`.
--      Their identity is the live row; their mmr and total_wins are not, because the chain
--      seeds every bot at 1000/0 and the live numbers drifted over months of play.
--   5. The starter deck template `decks.user_id = 0`, which V062 requires and no migration
--      creates. It predates the chain.
--   6. quests, reward_params, adventures, stages, scenarios, pve_scenario_* and decorations
--      -- 56 rows of definition data that no migration inserts.
--   7. The update_parameter_values_modtime trigger. V000 carries
--      update_updated_at_column() but not the CREATE TRIGGER statement, so the chain tip
--      has neither. parameter_values.updated_at is what made item 1 findable.
--      The chain tip's other overlaid trigger, update_magic_cards_modtime, went out with
--      `magic_cards`.
--
-- --------------------------------------------- where the live value was deliberately NOT taken
--
--   healing_totem, life_tree and rallying_totem `range` read 1.5, 1.5 and 2 in
--   wordonlinedev and 6 here. This is not drift and must not be overlaid.
--   V084_20260908__seed_magic_cast_parameters.sql redefined `range` on a magic-name game
--   object to be the cast range -- 6, taken from `build` -- and moved the old healing radius
--   to `effect_radius` first. This file carries effect_radius 1.5, 1.5 and 2 accordingly, so
--   both numbers survive. Writing the live value back over `range` would destroy the cast
--   range and duplicate a value that is already correct one column over.
--
--   magics.unlock_condition_type and unlock_required_value stay empty.
--   V085_20260908__move_magic_sync_and_unlock_columns.sql leaves them empty on purpose: no
--   element card maps to one magic, so which magic unlocks at how many wins is a content
--   decision for the admin screens after the relaunch.
--
--   Bot decks are the derived 15-card DEFAULT deck, not the live card rows.
--   V086_20260908__move_ownership_and_decks_to_magics.sql rebuilds every deck and records
--   that the old element and cast-type card rows have nothing to convert to.

--
-- PostgreSQL database dump
--


-- Dumped from database version 14.24
-- Dumped by pg_dump version 14.24

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS "public";


--
-- Name: bot_tier; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE "public"."bot_tier" AS ENUM (
    'INTRO',
    'BEGINNER',
    'INTERMEDIATE',
    'ADVANCED',
    'ELITE',
    'HOSPITALITY'
);


--
-- Name: card_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE "public"."card_type" AS ENUM (
    'Magic',
    'Type'
);


--
-- Name: game_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE "public"."game_type" AS ENUM (
    'PVP',
    'Practice',
    'PVE'
);


--
-- Name: user_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE "public"."user_status" AS ENUM (
    'Online',
    'OnMatching',
    'OnPlaying'
);


--
-- Name: allocate_bot_user_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."allocate_bot_user_id"() RETURNS bigint
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    candidate BIGINT;
BEGIN
    LOOP
        candidate := nextval('bot_user_id_seq');
        EXIT WHEN NOT EXISTS (SELECT 1 FROM users WHERE id = candidate);
    END LOOP;
    RETURN candidate;
END;
$$;


--
-- Name: sync_magic_tags_from_game_objects(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."sync_magic_tags_from_game_objects"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    inserted_count INTEGER;
BEGIN
    INSERT INTO magic_tags(magic_id, tag_id)
    SELECT resolved.magic_id, game_object_tag.tag_id
    FROM (SELECT magic.id                                     AS magic_id,
                 COALESCE(alias.game_object_name, magic.name) AS game_object_name
          FROM magics magic
                   LEFT JOIN magic_game_object_aliases alias ON alias.magic_name = magic.name) resolved
             JOIN game_objects game_object ON game_object.name = resolved.game_object_name
             JOIN game_object_tags game_object_tag ON game_object_tag.game_object_id = game_object.id
    WHERE NOT EXISTS (SELECT 1
                      FROM magic_tags existing
                      WHERE existing.magic_id = resolved.magic_id
                        AND existing.tag_id = game_object_tag.tag_id);

    GET DIAGNOSTICS inserted_count = ROW_COUNT;
    RETURN inserted_count;
END
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = "heap";

--
-- Name: adventures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."adventures" (
    "id" bigint NOT NULL,
    "name" character varying(31) NOT NULL,
    "access_type" character varying(10) DEFAULT 'FREE'::character varying NOT NULL
);


--
-- Name: adventures_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."adventures_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: adventures_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."adventures_id_seq" OWNED BY "public"."adventures"."id";


--
-- Name: bot_personas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."bot_personas" (
    "user_id" bigint NOT NULL,
    "name" character varying(50) NOT NULL,
    "tier" "public"."bot_tier" DEFAULT 'BEGINNER'::"public"."bot_tier" NOT NULL,
    "thinking_time_ms" integer DEFAULT 250 NOT NULL,
    "reaction_interval_frames" integer DEFAULT 8 NOT NULL,
    "counter_aggression" double precision DEFAULT 0.25 NOT NULL,
    "enabled" boolean DEFAULT true NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "hospitality" boolean DEFAULT false NOT NULL,
    CONSTRAINT "bot_personas_counter_aggression_check" CHECK ((("counter_aggression" >= ('-1.0'::numeric)::double precision) AND ("counter_aggression" <= (1.0)::double precision))),
    CONSTRAINT "bot_personas_reaction_interval_frames_check" CHECK (("reaction_interval_frames" >= 1)),
    CONSTRAINT "bot_personas_thinking_time_ms_check" CHECK (("thinking_time_ms" >= 0)),
    CONSTRAINT "chk_bot_personas_negative_user_id" CHECK (("user_id" < 0))
);


--
-- Name: bot_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."bot_user_id_seq"
    START WITH -1
    INCREMENT BY -1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deck_cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."deck_cards" (
    "id" bigint NOT NULL,
    "deck_id" bigint NOT NULL,
    "magic_id" bigint NOT NULL,
    "count" integer DEFAULT 1 NOT NULL
);


--
-- Name: deck_cards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."deck_cards_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deck_cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."deck_cards_id_seq" OWNED BY "public"."deck_cards"."id";


--
-- Name: decks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."decks" (
    "id" bigint NOT NULL,
    "name" character varying(31),
    "user_id" bigint NOT NULL
);


--
-- Name: decks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."decks_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: decks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."decks_id_seq" OWNED BY "public"."decks"."id";


--
-- Name: decorations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."decorations" (
    "id" bigint NOT NULL,
    "deco_type" character varying(10) NOT NULL,
    "name" character varying(20) NOT NULL
);


--
-- Name: decorations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."decorations_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: decorations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."decorations_id_seq" OWNED BY "public"."decorations"."id";


--
-- Name: deploy_status; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."deploy_status" (
    "id" bigint NOT NULL,
    "deploy_type" character varying(10) NOT NULL,
    "status" character varying(15) DEFAULT 'Healthy'::character varying NOT NULL
);


--
-- Name: deploy_status_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."deploy_status_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deploy_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."deploy_status_id_seq" OWNED BY "public"."deploy_status"."id";


--
-- Name: game_object_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."game_object_tags" (
    "id" bigint NOT NULL,
    "game_object_id" bigint,
    "tag_id" bigint
);


--
-- Name: game_object_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."game_object_tags_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: game_object_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."game_object_tags_id_seq" OWNED BY "public"."game_object_tags"."id";


--
-- Name: game_objects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."game_objects" (
    "id" bigint NOT NULL,
    "name" character varying(31)
);


--
-- Name: game_objects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."game_objects_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: game_objects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."game_objects_id_seq" OWNED BY "public"."game_objects"."id";


--
-- Name: magic_game_object_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."magic_game_object_aliases" (
    "magic_name" character varying(255) NOT NULL,
    "game_object_name" character varying(255) NOT NULL,
    "reason" "text" NOT NULL
);


--
-- Name: magic_parameters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."magic_parameters" (
    "id" bigint NOT NULL,
    "magic_id" bigint NOT NULL,
    "parameter_id" bigint NOT NULL,
    "value" double precision,
    "updated_at" timestamp without time zone DEFAULT "now"() NOT NULL
);


--
-- Name: magic_parameters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."magic_parameters_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: magic_parameters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."magic_parameters_id_seq" OWNED BY "public"."magic_parameters"."id";


--
-- Name: magic_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."magic_tags" (
    "magic_id" bigint NOT NULL,
    "tag_id" bigint NOT NULL
);


--
-- Name: magics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."magics" (
    "id" bigint NOT NULL,
    "name" character varying(255) NOT NULL,
    "access_type" character varying(10) DEFAULT 'DEFAULT'::character varying NOT NULL,
    "element" character varying(10) DEFAULT 'None'::character varying NOT NULL,
    "updated_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "unlock_condition_type" character varying(31),
    "unlock_required_value" integer,
    "cast_kind" character varying(16) NOT NULL,
    "prefab" character varying(63),
    "indicator" "jsonb" DEFAULT '{"layers": [{"shape": "circle", "origin": "target", "radius": {"parameter": "radius"}}], "version": 1}'::"jsonb" NOT NULL,
    CONSTRAINT "chk_magics_cast_kind" CHECK ((("cast_kind")::"text" = ANY ((ARRAY['Shot'::character varying, 'Drop'::character varying, 'Explosion'::character varying, 'Summon'::character varying, 'Spawn'::character varying, 'Code'::character varying])::"text"[]))),
    CONSTRAINT "chk_magics_element" CHECK ((("element")::"text" = ANY ((ARRAY['Fire'::character varying, 'Water'::character varying, 'Lightning'::character varying, 'Rock'::character varying, 'Nature'::character varying, 'Wind'::character varying, 'None'::character varying])::"text"[]))),
    CONSTRAINT "chk_magics_prefab_required" CHECK (((("cast_kind")::"text" = 'Code'::"text") OR ("prefab" IS NOT NULL)))
);


--
-- Name: magics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."magics_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: magics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."magics_id_seq" OWNED BY "public"."magics"."id";


--
-- Name: parameter_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."parameter_values" (
    "id" bigint NOT NULL,
    "parameter_id" bigint,
    "game_object_id" bigint,
    "value" double precision,
    "updated_at" timestamp without time zone DEFAULT "now"()
);


--
-- Name: parameter_values_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."parameter_values_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: parameter_values_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."parameter_values_id_seq" OWNED BY "public"."parameter_values"."id";


--
-- Name: parameters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."parameters" (
    "id" bigint NOT NULL,
    "name" character varying(31)
);


--
-- Name: parameters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."parameters_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: parameters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."parameters_id_seq" OWNED BY "public"."parameters"."id";


--
-- Name: prefab_elements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."prefab_elements" (
    "prefab" character varying(63) NOT NULL,
    "element" character varying(10) NOT NULL,
    CONSTRAINT "chk_prefab_elements_element" CHECK ((("element")::"text" = ANY ((ARRAY['Fire'::character varying, 'Water'::character varying, 'Lightning'::character varying, 'Rock'::character varying, 'Nature'::character varying, 'Wind'::character varying])::"text"[])))
);


--
-- Name: pve_scenario_event_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."pve_scenario_event_lines" (
    "id" bigint NOT NULL,
    "event_row_id" bigint NOT NULL,
    "line_order" integer NOT NULL,
    "line_text" character varying(255) NOT NULL
);


--
-- Name: pve_scenario_event_lines_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."pve_scenario_event_lines_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pve_scenario_event_lines_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."pve_scenario_event_lines_id_seq" OWNED BY "public"."pve_scenario_event_lines"."id";


--
-- Name: pve_scenario_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."pve_scenario_events" (
    "id" bigint NOT NULL,
    "event_id" character varying(50) NOT NULL,
    "trigger_type" character varying(50) NOT NULL,
    "trigger_value" integer NOT NULL,
    "speaker_installer_id" character varying(50),
    "message_key" character varying(100) NOT NULL,
    "sort_order" integer NOT NULL,
    "scenario_id" bigint DEFAULT 1 NOT NULL
);


--
-- Name: pve_scenario_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."pve_scenario_events_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pve_scenario_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."pve_scenario_events_id_seq" OWNED BY "public"."pve_scenario_events"."id";


--
-- Name: pve_scenario_installers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."pve_scenario_installers" (
    "id" bigint NOT NULL,
    "installer_id" character varying(50) NOT NULL,
    "prefab_type" character varying(50) NOT NULL,
    "master" character varying(20) NOT NULL,
    "position_x" integer NOT NULL,
    "position_y" integer NOT NULL,
    "position_z" integer NOT NULL,
    "sort_order" integer NOT NULL,
    "scenario_id" bigint DEFAULT 1 NOT NULL
);


--
-- Name: pve_scenario_installers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."pve_scenario_installers_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pve_scenario_installers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."pve_scenario_installers_id_seq" OWNED BY "public"."pve_scenario_installers"."id";


--
-- Name: pve_scenario_objectives; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."pve_scenario_objectives" (
    "id" bigint NOT NULL,
    "installer_id" character varying(50) NOT NULL,
    "sort_order" integer NOT NULL,
    "scenario_id" bigint DEFAULT 1 NOT NULL
);


--
-- Name: pve_scenario_objectives_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."pve_scenario_objectives_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pve_scenario_objectives_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."pve_scenario_objectives_id_seq" OWNED BY "public"."pve_scenario_objectives"."id";


--
-- Name: quests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."quests" (
    "id" bigint NOT NULL,
    "progress_checker" character varying(31),
    "require_value" integer NOT NULL,
    "reward_giver" character varying(31),
    "access_type" character varying(10) DEFAULT 'DEFAULT'::character varying NOT NULL
);


--
-- Name: quests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."quests_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."quests_id_seq" OWNED BY "public"."quests"."id";


--
-- Name: reward_params; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."reward_params" (
    "id" bigint NOT NULL,
    "quest_id" bigint,
    "name" character varying(31) NOT NULL,
    "value" integer NOT NULL
);


--
-- Name: reward_params_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."reward_params_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reward_params_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."reward_params_id_seq" OWNED BY "public"."reward_params"."id";


--
-- Name: scenarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."scenarios" (
    "id" bigint NOT NULL,
    "stage_id" bigint
);


--
-- Name: scenarios_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."scenarios_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scenarios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."scenarios_id_seq" OWNED BY "public"."scenarios"."id";


--
-- Name: servers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."servers" (
    "id" bigint NOT NULL,
    "protocol" character varying(10) NOT NULL,
    "domain" character varying(255) NOT NULL,
    "port" integer NOT NULL,
    "type" character varying(10) NOT NULL,
    "state" character varying(10) DEFAULT 'INACTIVE'::character varying NOT NULL,
    "last_heartbeat_at" timestamp with time zone,
    "session_count" integer DEFAULT 0 NOT NULL,
    "max_sessions" integer DEFAULT 100 NOT NULL,
    "instance_id" character varying(64),
    "target_bot_sessions" integer,
    "internal_base_url" character varying(255)
);


--
-- Name: servers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."servers_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: servers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."servers_id_seq" OWNED BY "public"."servers"."id";


--
-- Name: stages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."stages" (
    "id" bigint NOT NULL,
    "adventure_id" bigint
);


--
-- Name: stages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."stages_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."stages_id_seq" OWNED BY "public"."stages"."id";


--
-- Name: statistic_game_decks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."statistic_game_decks" (
    "id" bigint NOT NULL,
    "user_id" bigint NOT NULL,
    "statistic_game_id" bigint NOT NULL,
    "magic_id" bigint NOT NULL,
    "count" integer
);


--
-- Name: statistic_game_decks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."statistic_game_decks_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: statistic_game_decks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."statistic_game_decks_id_seq" OWNED BY "public"."statistic_game_decks"."id";


--
-- Name: statistic_game_magics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."statistic_game_magics" (
    "id" bigint NOT NULL,
    "user_id" bigint NOT NULL,
    "statistic_game_id" bigint,
    "magic_id" bigint NOT NULL,
    "count" integer
);


--
-- Name: statistic_game_magics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."statistic_game_magics_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: statistic_game_magics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."statistic_game_magics_id_seq" OWNED BY "public"."statistic_game_magics"."id";


--
-- Name: statistic_game_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."statistic_game_sessions" (
    "id" bigint NOT NULL,
    "session_id" character varying(128) NOT NULL,
    "left_user_id" bigint NOT NULL,
    "right_user_id" bigint NOT NULL,
    "game_type" "public"."game_type" NOT NULL,
    "server_domain" character varying(255) NOT NULL,
    "server_port" integer NOT NULL,
    "server_instance_id" character varying(64) NOT NULL,
    "server_version" character varying(64) NOT NULL,
    "status" character varying(16) DEFAULT 'IN_PROGRESS'::character varying NOT NULL,
    "end_reason" character varying(32),
    "end_detail" "text",
    "statistic_game_id" bigint,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ended_at" timestamp with time zone,
    CONSTRAINT "statistic_game_sessions_status_check" CHECK ((("status")::"text" = ANY ((ARRAY['IN_PROGRESS'::character varying, 'COMPLETED'::character varying, 'DRAW'::character varying, 'ABANDONED'::character varying])::"text"[])))
);


--
-- Name: statistic_game_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."statistic_game_sessions_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: statistic_game_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."statistic_game_sessions_id_seq" OWNED BY "public"."statistic_game_sessions"."id";


--
-- Name: statistic_games; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."statistic_games" (
    "id" bigint NOT NULL,
    "win_user_id" bigint,
    "loss_user_id" bigint,
    "duration" bigint NOT NULL,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "game_type" "public"."game_type" DEFAULT 'PVP'::"public"."game_type" NOT NULL,
    "server_version" character varying(64) NOT NULL,
    "event_schema_version" integer NOT NULL,
    "outcome" character varying(16) DEFAULT 'WIN'::character varying NOT NULL,
    CONSTRAINT "chk_statistic_games_event_schema_version" CHECK (("event_schema_version" > 0)),
    CONSTRAINT "statistic_games_outcome_check" CHECK ((("outcome")::"text" = ANY ((ARRAY['WIN'::character varying, 'DRAW'::character varying, 'ABANDONED'::character varying])::"text"[]))),
    CONSTRAINT "statistic_games_win_outcome_check" CHECK (((("outcome")::"text" <> 'WIN'::"text") OR (("win_user_id" IS NOT NULL) AND ("loss_user_id" IS NOT NULL))))
);


--
-- Name: statistic_games_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."statistic_games_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: statistic_games_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."statistic_games_id_seq" OWNED BY "public"."statistic_games"."id";


--
-- Name: statistic_update_time; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."statistic_update_time" (
    "id" bigint NOT NULL,
    "statistic_game_id" bigint,
    "name" character varying(31),
    "min_interval_ns" bigint,
    "max_interval_ns" bigint,
    "mean_interval_ns" double precision
);


--
-- Name: statistic_update_time_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."statistic_update_time_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: statistic_update_time_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."statistic_update_time_id_seq" OWNED BY "public"."statistic_update_time"."id";


--
-- Name: tag_counter_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."tag_counter_rules" (
    "id" bigint NOT NULL,
    "attacker_tag_id" bigint NOT NULL,
    "target_tag_id" bigint NOT NULL,
    "weight" double precision DEFAULT 1.0 NOT NULL
);


--
-- Name: tag_counter_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."tag_counter_rules_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_counter_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."tag_counter_rules_id_seq" OWNED BY "public"."tag_counter_rules"."id";


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."tags" (
    "id" bigint NOT NULL,
    "name" character varying(20)
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."tags_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."tags_id_seq" OWNED BY "public"."tags"."id";


--
-- Name: user_adventures_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."user_adventures_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_decorations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."user_decorations" (
    "id" bigint NOT NULL,
    "user_id" bigint,
    "decoration_id" bigint,
    "is_equipped" boolean DEFAULT false
);


--
-- Name: user_decorations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."user_decorations_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_decorations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."user_decorations_id_seq" OWNED BY "public"."user_decorations"."id";


--
-- Name: user_magics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."user_magics" (
    "id" bigint NOT NULL,
    "user_id" bigint,
    "magic_id" bigint,
    "count" integer DEFAULT 3 NOT NULL
);


--
-- Name: user_magics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."user_magics_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_magics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."user_magics_id_seq" OWNED BY "public"."user_magics"."id";


--
-- Name: user_quests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."user_quests" (
    "id" bigint NOT NULL,
    "user_id" bigint,
    "quest_id" bigint,
    "state" character varying(15) DEFAULT 'IN_PROGRESS'::character varying NOT NULL
);


--
-- Name: user_quests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."user_quests_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_quests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."user_quests_id_seq" OWNED BY "public"."user_quests"."id";


--
-- Name: user_scenarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."user_scenarios" (
    "id" bigint NOT NULL,
    "user_id" bigint,
    "scenario_id" bigint,
    "state" character varying(10) DEFAULT 'INACTIVE'::character varying NOT NULL
);


--
-- Name: user_scenarios_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."user_scenarios_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_scenarios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."user_scenarios_id_seq" OWNED BY "public"."user_scenarios"."id";


--
-- Name: user_stages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."user_stages_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."users" (
    "id" bigint NOT NULL,
    "selected_deck_id" bigint,
    "mmr" smallint DEFAULT 1000 NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "status" character varying(20) DEFAULT 'Online'::"public"."user_status" NOT NULL,
    "total_wins" integer DEFAULT 0 NOT NULL,
    "novice_progress" real DEFAULT 0.5 NOT NULL,
    CONSTRAINT "chk_users_novice_progress" CHECK ((("novice_progress" >= (0.5)::double precision) AND ("novice_progress" <= (1.0)::double precision)))
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."users_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."users_id_seq" OWNED BY "public"."users"."id";


--
-- Name: adventures id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."adventures" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."adventures_id_seq"'::"regclass");


--
-- Name: deck_cards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."deck_cards" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."deck_cards_id_seq"'::"regclass");


--
-- Name: decks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."decks" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."decks_id_seq"'::"regclass");


--
-- Name: decorations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."decorations" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."decorations_id_seq"'::"regclass");


--
-- Name: deploy_status id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."deploy_status" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."deploy_status_id_seq"'::"regclass");


--
-- Name: game_object_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."game_object_tags" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."game_object_tags_id_seq"'::"regclass");


--
-- Name: game_objects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."game_objects" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."game_objects_id_seq"'::"regclass");


--
-- Name: magic_parameters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."magic_parameters" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."magic_parameters_id_seq"'::"regclass");


--
-- Name: magics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."magics" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."magics_id_seq"'::"regclass");


--
-- Name: parameter_values id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."parameter_values" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."parameter_values_id_seq"'::"regclass");


--
-- Name: parameters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."parameters" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."parameters_id_seq"'::"regclass");


--
-- Name: pve_scenario_event_lines id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."pve_scenario_event_lines" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."pve_scenario_event_lines_id_seq"'::"regclass");


--
-- Name: pve_scenario_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."pve_scenario_events" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."pve_scenario_events_id_seq"'::"regclass");


--
-- Name: pve_scenario_installers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."pve_scenario_installers" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."pve_scenario_installers_id_seq"'::"regclass");


--
-- Name: pve_scenario_objectives id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."pve_scenario_objectives" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."pve_scenario_objectives_id_seq"'::"regclass");


--
-- Name: quests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."quests" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."quests_id_seq"'::"regclass");


--
-- Name: reward_params id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."reward_params" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."reward_params_id_seq"'::"regclass");


--
-- Name: scenarios id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."scenarios" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."scenarios_id_seq"'::"regclass");


--
-- Name: servers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."servers" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."servers_id_seq"'::"regclass");


--
-- Name: stages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stages" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."stages_id_seq"'::"regclass");


--
-- Name: statistic_game_decks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."statistic_game_decks" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."statistic_game_decks_id_seq"'::"regclass");


--
-- Name: statistic_game_magics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."statistic_game_magics" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."statistic_game_magics_id_seq"'::"regclass");


--
-- Name: statistic_game_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."statistic_game_sessions" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."statistic_game_sessions_id_seq"'::"regclass");


--
-- Name: statistic_games id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."statistic_games" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."statistic_games_id_seq"'::"regclass");


--
-- Name: statistic_update_time id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."statistic_update_time" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."statistic_update_time_id_seq"'::"regclass");


--
-- Name: tag_counter_rules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."tag_counter_rules" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."tag_counter_rules_id_seq"'::"regclass");


--
-- Name: tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."tags" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."tags_id_seq"'::"regclass");


--
-- Name: user_decorations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_decorations" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."user_decorations_id_seq"'::"regclass");


--
-- Name: user_magics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_magics" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."user_magics_id_seq"'::"regclass");


--
-- Name: user_quests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_quests" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."user_quests_id_seq"'::"regclass");


--
-- Name: user_scenarios id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_scenarios" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."user_scenarios_id_seq"'::"regclass");


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."users" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."users_id_seq"'::"regclass");


--
-- Data for Name: adventures; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."adventures" ("id", "name", "access_type") VALUES (1, 'forest', 'FREE');


--
-- Data for Name: bot_personas; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-17, 'Sky Hatchling', 'INTRO', 1200, 24, 0.1, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-18, 'Cloud Cadet', 'BEGINNER', 850, 16, 0.25, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-19, 'Storm Captain', 'INTERMEDIATE', 500, 10, 0.5, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-20, 'Tempest Regent', 'ADVANCED', 250, 6, 0.75, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-21, 'Celestial Emperor', 'ELITE', 75, 2, 0.95, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-22, 'Ember Tinkerer', 'INTRO', 1200, 24, 0.1, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-23, 'Lava Enthusiast', 'BEGINNER', 850, 16, 0.25, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-24, 'Magma Addict', 'INTERMEDIATE', 500, 10, 0.5, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-25, 'Caldera Fanatic', 'ADVANCED', 250, 6, 0.75, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-26, 'Volcanic Maniac', 'ELITE', 75, 2, 0.95, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-27, 'Reckless Rookie', 'INTRO', 1200, 24, 0.1, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-28, 'Face Rusher', 'BEGINNER', 850, 16, 0.25, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-29, 'Relentless Striker', 'INTERMEDIATE', 500, 10, 0.5, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-30, 'Lethal Hunter', 'ADVANCED', 250, 6, 0.75, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-31, 'Facebreaker', 'ELITE', 75, 2, 0.95, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-32, 'Tiny Wrangler', 'INTRO', 1200, 24, 0.1, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-33, 'Swarm Keeper', 'BEGINNER', 850, 16, 0.25, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-34, 'Minion Tactician', 'INTERMEDIATE', 500, 10, 0.5, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-35, 'Horde Commander', 'ADVANCED', 250, 6, 0.75, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-36, 'Minion Master', 'ELITE', 75, 2, 0.95, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-37, 'Sprout Scout', 'INTRO', 1200, 24, 0.1, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-38, 'Vine Trainer', 'BEGINNER', 850, 16, 0.25, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-39, 'Grove Keeper', 'INTERMEDIATE', 500, 10, 0.5, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-40, 'Verdant Captain', 'ADVANCED', 250, 6, 0.75, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-41, 'Grass Gym Leader', 'ELITE', 75, 2, 0.95, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-42, 'Static Spark', 'INTRO', 1200, 24, 0.1, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-43, 'Volt Rookie', 'BEGINNER', 850, 16, 0.25, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-44, 'Thunder Charger', 'INTERMEDIATE', 500, 10, 0.5, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-45, 'Lightning Ace', 'ADVANCED', 250, 6, 0.75, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-46, 'Shock Supreme', 'ELITE', 75, 2, 0.95, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-47, 'Splash Rookie', 'INTRO', 1200, 24, 0.1, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-48, 'Bubble Bomber', 'BEGINNER', 850, 16, 0.25, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-49, 'Torrent Blaster', 'INTERMEDIATE', 500, 10, 0.5, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-50, 'Tidal Demolitionist', 'ADVANCED', 250, 6, 0.75, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-51, 'Water Bomb Maniac', 'ELITE', 75, 2, 0.95, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-52, 'Novice Caller', 'INTRO', 1200, 24, 0.1, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-53, 'Familiar Keeper', 'BEGINNER', 850, 16, 0.25, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-54, 'Spirit Invoker', 'INTERMEDIATE', 500, 10, 0.5, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-55, 'Rift Conjurer', 'ADVANCED', 250, 6, 0.75, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-56, 'Grand Summoner', 'ELITE', 75, 2, 0.95, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-57, 'Pebble Caller', 'INTRO', 1200, 24, 0.1, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-58, 'Minirock Keeper', 'BEGINNER', 850, 16, 0.25, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-59, 'Stone Shaper', 'INTERMEDIATE', 500, 10, 0.5, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-60, 'Golem Architect', 'ADVANCED', 250, 6, 0.75, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-61, 'Colossus Summoner', 'ELITE', 75, 2, 0.95, true, '2026-09-16 10:06:02.663011', '2026-09-16 10:06:02.663011', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-62, 'Warm Welcome', 'HOSPITALITY', 1200, 30, -1, true, '2026-09-16 10:06:03.099362', '2026-09-16 10:06:03.099362', true);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-1, 'Beginner Bot', 'BEGINNER', 1000, 8, 0, false, '2026-09-16 10:11:17.919237', '2026-09-16 10:11:17.919237', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-6, 'Elite Bot', 'ELITE', 4, 1, 1, false, '2026-09-16 10:11:17.919237', '2026-09-16 10:11:17.919237', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-7, 'Beginner Bot A', 'BEGINNER', 400, 8, 0.25, false, '2026-09-16 10:11:17.919237', '2026-09-16 10:11:17.919237', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-8, 'Intro Bot A', 'INTRO', 700, 14, 0.05, false, '2026-09-16 10:11:17.919237', '2026-09-16 10:11:17.919237', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-9, 'Intro Bot B', 'INTRO', 650, 13, 0.1, false, '2026-09-16 10:11:17.919237', '2026-09-16 10:11:17.919237', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-10, 'Beginner Bot B', 'BEGINNER', 450, 9, 0.25, false, '2026-09-16 10:11:17.919237', '2026-09-16 10:11:17.919237', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-11, 'Intermediate Bot A', 'INTERMEDIATE', 350, 7, 0.4, false, '2026-09-16 10:11:17.919237', '2026-09-16 10:11:17.919237', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-12, 'Intermediate Bot B', 'INTERMEDIATE', 320, 7, 0.45, false, '2026-09-16 10:11:17.919237', '2026-09-16 10:11:17.919237', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-13, 'Advanced Bot A', 'ADVANCED', 260, 5, 0.65, false, '2026-09-16 10:11:17.919237', '2026-09-16 10:11:17.919237', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-14, 'Advanced Bot B', 'ADVANCED', 240, 5, 0.7, false, '2026-09-16 10:11:17.919237', '2026-09-16 10:11:17.919237', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-15, 'Elite Bot A', 'ELITE', 180, 3, 0.85, false, '2026-09-16 10:11:17.919237', '2026-09-16 10:11:17.919237', false);
INSERT INTO "public"."bot_personas" ("user_id", "name", "tier", "thinking_time_ms", "reaction_interval_frames", "counter_aggression", "enabled", "created_at", "updated_at", "hospitality") VALUES (-16, 'Elite Bot B', 'ELITE', 160, 3, 0.95, false, '2026-09-16 10:11:17.919237', '2026-09-16 10:11:17.919237', false);


--
-- Data for Name: deck_cards; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (475, 47, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (476, 47, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (477, 47, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (478, 47, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (479, 47, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (480, 48, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (481, 48, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (482, 48, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (483, 48, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (484, 48, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (485, 49, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (486, 49, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (487, 49, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (488, 49, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (489, 49, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (490, 50, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (491, 50, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (492, 50, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (493, 50, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (494, 50, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (495, 51, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (496, 51, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (497, 51, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (498, 51, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (499, 51, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (500, 52, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (501, 52, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (502, 52, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (503, 52, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (504, 52, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (505, 53, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (506, 53, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (507, 53, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (508, 53, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (509, 53, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (510, 54, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (511, 54, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (512, 54, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (513, 54, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (514, 54, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (515, 55, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (516, 55, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (517, 55, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (518, 55, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (519, 55, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (520, 56, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (521, 56, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (522, 56, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (523, 56, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (524, 56, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (525, 57, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (526, 57, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (527, 57, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (528, 57, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (529, 57, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (530, 58, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (531, 58, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (532, 58, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (533, 58, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (534, 58, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (535, 59, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (536, 59, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (537, 59, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (538, 59, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (539, 59, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (240, 0, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (241, 0, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (242, 0, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (243, 0, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (244, 0, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (245, 1, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (246, 1, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (247, 1, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (248, 1, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (249, 1, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (250, 2, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (251, 2, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (252, 2, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (253, 2, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (254, 2, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (255, 3, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (256, 3, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (257, 3, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (258, 3, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (259, 3, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (260, 4, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (261, 4, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (262, 4, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (263, 4, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (264, 4, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (265, 5, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (266, 5, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (267, 5, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (268, 5, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (269, 5, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (270, 6, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (271, 6, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (272, 6, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (273, 6, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (274, 6, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (275, 7, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (276, 7, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (277, 7, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (278, 7, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (279, 7, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (280, 8, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (281, 8, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (282, 8, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (283, 8, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (284, 8, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (285, 9, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (286, 9, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (287, 9, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (288, 9, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (289, 9, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (290, 10, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (291, 10, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (292, 10, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (293, 10, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (294, 10, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (295, 11, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (296, 11, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (297, 11, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (298, 11, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (299, 11, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (300, 12, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (301, 12, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (302, 12, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (303, 12, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (304, 12, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (305, 13, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (306, 13, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (307, 13, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (308, 13, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (309, 13, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (310, 14, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (311, 14, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (312, 14, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (313, 14, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (314, 14, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (315, 15, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (316, 15, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (317, 15, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (318, 15, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (319, 15, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (320, 16, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (321, 16, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (322, 16, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (323, 16, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (324, 16, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (325, 17, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (326, 17, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (327, 17, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (328, 17, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (329, 17, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (330, 18, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (331, 18, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (332, 18, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (333, 18, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (334, 18, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (335, 19, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (336, 19, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (337, 19, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (338, 19, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (339, 19, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (340, 20, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (341, 20, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (342, 20, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (343, 20, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (344, 20, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (345, 21, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (346, 21, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (347, 21, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (348, 21, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (349, 21, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (350, 22, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (351, 22, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (352, 22, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (353, 22, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (354, 22, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (355, 23, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (356, 23, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (357, 23, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (358, 23, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (359, 23, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (360, 24, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (361, 24, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (362, 24, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (363, 24, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (364, 24, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (365, 25, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (366, 25, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (367, 25, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (368, 25, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (369, 25, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (370, 26, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (371, 26, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (372, 26, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (373, 26, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (374, 26, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (375, 27, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (376, 27, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (377, 27, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (378, 27, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (379, 27, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (380, 28, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (381, 28, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (382, 28, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (383, 28, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (384, 28, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (385, 29, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (386, 29, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (387, 29, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (388, 29, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (389, 29, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (390, 30, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (391, 30, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (392, 30, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (393, 30, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (394, 30, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (395, 31, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (396, 31, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (397, 31, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (398, 31, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (399, 31, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (400, 32, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (401, 32, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (402, 32, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (403, 32, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (404, 32, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (405, 33, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (406, 33, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (407, 33, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (408, 33, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (409, 33, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (410, 34, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (411, 34, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (412, 34, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (413, 34, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (414, 34, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (415, 35, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (416, 35, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (417, 35, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (418, 35, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (419, 35, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (420, 36, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (421, 36, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (422, 36, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (423, 36, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (424, 36, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (425, 37, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (426, 37, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (427, 37, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (428, 37, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (429, 37, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (430, 38, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (431, 38, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (432, 38, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (433, 38, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (434, 38, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (435, 39, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (436, 39, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (437, 39, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (438, 39, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (439, 39, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (440, 40, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (441, 40, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (442, 40, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (443, 40, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (444, 40, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (445, 41, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (446, 41, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (447, 41, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (448, 41, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (449, 41, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (450, 42, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (451, 42, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (452, 42, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (453, 42, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (454, 42, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (455, 43, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (456, 43, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (457, 43, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (458, 43, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (459, 43, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (460, 44, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (461, 44, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (462, 44, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (463, 44, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (464, 44, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (465, 45, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (466, 45, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (467, 45, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (468, 45, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (469, 45, 54, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (470, 46, 55, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (471, 46, 24, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (472, 46, 35, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (473, 46, 19, 3);
INSERT INTO "public"."deck_cards" ("id", "deck_id", "magic_id", "count") VALUES (474, 46, 54, 3);


--
-- Data for Name: decks; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (0, 'Starter Deck', 0);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (1, 'Skies · INTRO', -17);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (2, 'Skies · BEGINNER', -18);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (3, 'Skies · INTERMEDIATE', -19);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (4, 'Skies · ADVANCED', -20);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (5, 'Skies · ELITE', -21);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (6, 'Magma · INTRO', -22);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (7, 'Magma · BEGINNER', -23);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (8, 'Magma · INTERMEDIATE', -24);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (9, 'Magma · ADVANCED', -25);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (10, 'Magma · ELITE', -26);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (11, 'Face · INTRO', -27);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (12, 'Face · BEGINNER', -28);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (13, 'Face · INTERMEDIATE', -29);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (14, 'Face · ADVANCED', -30);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (15, 'Face · ELITE', -31);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (16, 'Minions · INTRO', -32);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (17, 'Minions · BEGINNER', -33);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (18, 'Minions · INTERMEDIATE', -34);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (19, 'Minions · ADVANCED', -35);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (20, 'Minions · ELITE', -36);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (21, 'Grass · INTRO', -37);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (22, 'Grass · BEGINNER', -38);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (23, 'Grass · INTERMEDIATE', -39);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (24, 'Grass · ADVANCED', -40);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (25, 'Grass · ELITE', -41);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (26, 'Shock · INTRO', -42);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (27, 'Shock · BEGINNER', -43);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (28, 'Shock · INTERMEDIATE', -44);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (29, 'Shock · ADVANCED', -45);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (30, 'Shock · ELITE', -46);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (31, 'Water Bomb · INTRO', -47);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (32, 'Water Bomb · BEGINNER', -48);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (33, 'Water Bomb · INTERMEDIATE', -49);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (34, 'Water Bomb · ADVANCED', -50);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (35, 'Water Bomb · ELITE', -51);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (36, 'Summoner · INTRO', -52);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (37, 'Summoner · BEGINNER', -53);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (38, 'Summoner · INTERMEDIATE', -54);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (39, 'Summoner · ADVANCED', -55);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (40, 'Summoner · ELITE', -56);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (41, 'Golems · INTRO', -57);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (42, 'Golems · BEGINNER', -58);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (43, 'Golems · INTERMEDIATE', -59);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (44, 'Golems · ADVANCED', -60);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (45, 'Golems · ELITE', -61);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (46, 'Warm Welcome', -62);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (47, '봇의 기본 덱', -1);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (48, 'Starter Deck', -1);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (49, 'Starter Deck', -6);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (50, '봇의 기본 덱', -7);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (51, '봇의 기본 덱', -8);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (52, '봇의 기본 덱', -9);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (53, '봇의 기본 덱', -10);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (54, '봇의 기본 덱', -11);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (55, '봇의 기본 덱', -12);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (56, '봇의 기본 덱', -13);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (57, '봇의 기본 덱', -14);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (58, '봇의 기본 덱', -15);
INSERT INTO "public"."decks" ("id", "name", "user_id") VALUES (59, '봇의 기본 덱', -16);


--
-- Data for Name: decorations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."decorations" ("id", "deco_type", "name") VALUES (1, 'Hat', 'leaf_hat');
INSERT INTO "public"."decorations" ("id", "deco_type", "name") VALUES (2, 'Cape', 'leaf_cape');
INSERT INTO "public"."decorations" ("id", "deco_type", "name") VALUES (3, 'Hat', 'ancient_hat');
INSERT INTO "public"."decorations" ("id", "deco_type", "name") VALUES (4, 'Cape', 'ancient_cape');


--
-- Data for Name: game_object_tags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (147, 184, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (148, 164, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (149, 163, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (150, 157, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (151, 155, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (152, 152, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (153, 140, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (154, 105, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (155, 104, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (156, 103, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (157, 102, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (158, 101, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (159, 100, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (160, 99, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (161, 98, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (162, 97, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (163, 96, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (164, 95, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (165, 94, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (166, 93, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (167, 92, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (168, 91, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (169, 90, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (170, 89, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (171, 88, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (172, 87, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (173, 86, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (174, 85, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (175, 84, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (176, 83, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (177, 82, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (178, 81, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (179, 80, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (180, 79, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (181, 78, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (182, 77, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (183, 76, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (184, 75, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (185, 74, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (186, 73, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (187, 72, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (188, 71, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (189, 70, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (190, 69, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (191, 68, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (192, 67, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (193, 66, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (194, 64, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (195, 63, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (196, 62, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (197, 61, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (198, 60, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (199, 59, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (200, 57, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (201, 56, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (202, 55, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (203, 54, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (204, 53, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (205, 51, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (206, 48, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (207, 46, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (208, 45, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (209, 44, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (210, 40, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (211, 38, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (212, 37, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (213, 36, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (214, 35, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (215, 34, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (216, 33, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (217, 27, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (218, 26, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (219, 25, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (220, 24, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (221, 23, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (222, 22, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (223, 18, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (224, 17, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (225, 15, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (226, 14, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (227, 13, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (228, 12, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (229, 11, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (230, 1, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (231, 184, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (232, 157, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (233, 86, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (234, 85, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (235, 84, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (236, 83, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (237, 82, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (238, 81, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (239, 80, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (240, 79, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (241, 77, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (242, 76, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (243, 75, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (244, 73, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (245, 63, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (246, 60, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (247, 56, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (248, 54, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (249, 38, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (250, 37, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (251, 34, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (252, 11, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (253, 1, 2);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (254, 164, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (255, 163, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (256, 140, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (257, 87, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (258, 78, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (259, 75, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (260, 73, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (261, 71, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (262, 69, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (263, 68, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (264, 67, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (265, 57, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (266, 56, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (267, 55, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (268, 45, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (269, 44, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (270, 38, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (271, 37, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (272, 34, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (273, 27, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (274, 23, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (275, 22, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (276, 18, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (277, 17, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (278, 15, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (279, 13, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (280, 12, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (281, 184, 4);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (282, 75, 4);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (283, 73, 4);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (284, 69, 4);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (285, 51, 4);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (286, 38, 4);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (287, 37, 4);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (288, 11, 4);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (289, 155, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (290, 152, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (291, 140, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (292, 105, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (293, 104, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (294, 103, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (295, 102, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (296, 97, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (297, 96, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (298, 95, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (299, 94, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (300, 93, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (301, 92, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (302, 91, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (303, 90, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (304, 89, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (305, 88, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (306, 78, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (307, 74, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (308, 72, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (309, 68, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (310, 66, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (311, 64, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (312, 62, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (313, 61, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (314, 59, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (315, 56, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (316, 48, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (317, 46, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (318, 45, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (319, 44, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (320, 40, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (321, 38, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (322, 26, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (323, 25, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (324, 22, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (325, 15, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (326, 14, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (327, 164, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (328, 140, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (329, 101, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (330, 100, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (331, 99, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (332, 98, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (333, 78, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (334, 71, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (335, 68, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (336, 67, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (337, 62, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (338, 57, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (339, 55, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (340, 45, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (341, 33, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (342, 24, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (343, 23, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (344, 22, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (345, 205, 7);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (346, 190, 7);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (347, 176, 7);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (348, 161, 7);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (349, 139, 7);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (350, 126, 7);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (351, 49, 7);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (352, 6, 7);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (353, 2, 7);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (354, 201, 8);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (355, 194, 8);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (356, 167, 8);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (357, 158, 8);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (358, 148, 8);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (359, 127, 8);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (360, 116, 8);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (361, 5, 8);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (362, 4, 8);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (363, 3, 8);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (364, 2, 8);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (365, 51, 9);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (366, 36, 9);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (367, 70, 10);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (368, 69, 10);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (369, 53, 10);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (370, 44, 10);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (371, 35, 10);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (372, 184, 11);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (373, 77, 11);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (374, 76, 11);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (375, 60, 11);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (376, 36, 11);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (377, 53, 12);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (378, 44, 12);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (379, 35, 12);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (380, 93, 13);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (381, 63, 13);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (382, 54, 13);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (383, 51, 13);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (384, 48, 13);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (385, 46, 13);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (386, 38, 13);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (387, 24, 13);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (388, 14, 13);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (389, 211, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (390, 211, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (391, 212, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (392, 212, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (393, 212, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (394, 212, 10);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (395, 213, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (396, 213, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (397, 216, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (398, 216, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (399, 216, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (400, 217, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (401, 29, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (402, 29, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (403, 30, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (404, 30, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (405, 16, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (406, 16, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (407, 1, 11);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (408, 82, 11);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (409, 85, 11);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (410, 84, 11);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (411, 86, 11);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (412, 83, 11);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (413, 157, 11);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (414, 79, 11);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (415, 80, 11);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (416, 81, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (417, 11, 11);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (418, 11, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (419, 163, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (420, 218, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (421, 218, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (422, 218, 10);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (423, 218, 13);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (424, 219, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (425, 219, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (426, 219, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (427, 219, 10);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (428, 220, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (429, 220, 9);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (430, 220, 11);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (431, 222, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (432, 222, 10);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (433, 222, 11);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (434, 222, 12);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (435, 223, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (436, 223, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (437, 223, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (438, 223, 13);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (439, 224, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (440, 224, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (441, 225, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (442, 225, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (443, 225, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (444, 226, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (445, 226, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (446, 226, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (447, 226, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (448, 227, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (449, 227, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (450, 228, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (451, 228, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (452, 228, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (453, 229, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (454, 229, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (455, 230, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (456, 230, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (457, 230, 6);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (458, 230, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (459, 231, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (460, 231, 7);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (461, 232, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (462, 232, 7);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (463, 233, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (464, 233, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (465, 233, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (466, 234, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (467, 234, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (468, 234, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (469, 235, 13);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (470, 235, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (471, 235, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (472, 236, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (473, 236, 3);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (474, 236, 4);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (475, 236, 1);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (476, 237, 5);
INSERT INTO "public"."game_object_tags" ("id", "game_object_id", "tag_id") VALUES (477, 237, 7);


--
-- Data for Name: game_objects; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."game_objects" ("id", "name") VALUES (1, 'slime');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (2, 'shoot');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (3, 'explode');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (4, 'spawn');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (5, 'build');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (6, 'field');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (7, 'ember_spirit_swarm');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (8, 'water_slime_swarm');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (9, 'mini_rock_swarm');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (10, 'seed_spirit_swarm');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (11, 'wind_spirit');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (12, 'water_shot');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (13, 'fire_shot');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (14, 'tide_call');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (15, 'chain_lightning');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (16, 'vine_toss');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (17, 'rock_rolling');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (18, 'wind_blade');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (20, 'fire_slime_nest');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (21, 'water_slime_nest');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (22, 'life_tree');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (23, 'rock_turret');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (24, 'wind_totem');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (25, 'magma_explosion');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (26, 'water_explosion');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (27, 'will_o_wisp');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (29, 'frenzy_totem');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (30, 'leafair');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (31, 'cannon');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (32, 'tower');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (33, 'mana_well');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (34, 'aqua_archer');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (35, 'rock_golem');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (36, 'storm_rider');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (37, 'thunder_spirit');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (38, 'fire_spirit');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (40, 'lightning_drop');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (41, 'wind_explosion');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (44, 'magma_spirit');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (45, 'healing_totem');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (46, 'sand_storm');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (48, 'tornado_strike');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (49, 'meteor_shower');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (50, 'lightning_shot');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (51, 'cloud_dragon');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (52, 'thunder_bird_swarm');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (53, 'tree_golem');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (54, 'vine_spirit');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (55, 'vine_colony');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (56, 'rock_mage');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (57, 'pve_nature_slime_nest');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (59, 'rock_drop');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (60, 'chicken_commando');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (61, 'overgrowth');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (62, 'crater');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (63, 'zap_mouse');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (65, 'lightning_explosion');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (66, 'razor_gale');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (67, 'bubble_generator');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (68, 'electric_tower');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (69, 'fire_lord_spirit');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (70, 'dimension_toad');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (71, 'towerback');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (72, 'shock_overload');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (73, 'bubble_spirit');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (74, 'crater_ember');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (75, 'fire_child_spirit');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (76, 'lightning_tadpole');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (77, 'fire_tadpole');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (78, 'ground_tower');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (79, 'ember_spirit');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (80, 'seed_spirit');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (81, 'water_slime');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (82, 'fire_slime');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (83, 'electric_slime');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (84, 'leaf_slime');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (85, 'rock_slime');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (86, 'wind_slime');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (87, 'electric_shot');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (88, 'fire_explode');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (89, 'water_explode');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (90, 'leaf_explode');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (91, 'rock_explode');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (92, 'electric_explode');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (93, 'wind_explode');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (94, 'fire_drop');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (95, 'nature_drop');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (96, 'leaf_drop');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (97, 'wind_drop');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (98, 'fire_summon');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (99, 'electric_summon');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (100, 'rock_summon');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (101, 'wind_summon');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (102, 'fire_field');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (103, 'water_field');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (104, 'electric_field');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (105, 'leaf_field');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (116, 'drop');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (126, 'field_short');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (127, 'fire');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (139, 'game');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (140, 'ground_cannon');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (148, 'lightning');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (152, 'magma_fist');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (155, 'meteor_drop');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (157, 'mini_rock');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (158, 'nature');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (161, 'player');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (163, 'pve_vine_witch');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (164, 'pve_water_slime_nest');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (167, 'rock');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (176, 'rune');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (184, 'thunder_bird');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (190, 'vine');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (194, 'water');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (201, 'wind');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (205, 'wind_shoot');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (211, 'seed_nest');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (212, 'giant_vine');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (64, 'rallying_totem');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (213, 'lightning_cloud');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (216, 'pve_vine_colony');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (217, 'rock_remnant');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (218, 'evil_ent');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (219, 'sea_serpent');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (220, 'storm_stag');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (221, 'vine_world');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (222, 'wall_golem');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (223, 'shock_trap');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (224, 'repair_totem');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (225, 'grass_generator');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (226, 'dragon_tower');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (227, 'dragon_flame');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (228, 'firework_tower');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (229, 'firework_shell');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (230, 'titan_remnant');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (231, 'titan_fist');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (232, 'spirit_bomb');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (233, 'tidal_warhead');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (234, 'ground_tidal_warhead');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (235, 'boulder_strike');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (236, 'bomb_sprite');
INSERT INTO "public"."game_objects" ("id", "name") VALUES (237, 'bomb_sprite_bomb');


--
-- Data for Name: magic_game_object_aliases; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."magic_game_object_aliases" ("magic_name", "game_object_name", "reason") VALUES ('ember_spirit_swarm', 'ember_spirit', 'EmberSpiritSwarmMagic spawns PrefabType.EmberSpirit');
INSERT INTO "public"."magic_game_object_aliases" ("magic_name", "game_object_name", "reason") VALUES ('mini_rock_swarm', 'mini_rock', 'MiniRockSwarmMagic spawns PrefabType.MiniRock');
INSERT INTO "public"."magic_game_object_aliases" ("magic_name", "game_object_name", "reason") VALUES ('seed_spirit_swarm', 'seed_spirit', 'SeedSpiritSwarmMagic spawns PrefabType.SeedSpirit');
INSERT INTO "public"."magic_game_object_aliases" ("magic_name", "game_object_name", "reason") VALUES ('thunder_bird_swarm', 'thunder_bird', 'thunderBirdSwarmMagic spawns PrefabType.ThunderBird');
INSERT INTO "public"."magic_game_object_aliases" ("magic_name", "game_object_name", "reason") VALUES ('water_slime_swarm', 'water_slime', 'WaterSlimeSwarmMagic spawns PrefabType.WaterSlime');
INSERT INTO "public"."magic_game_object_aliases" ("magic_name", "game_object_name", "reason") VALUES ('cannon', 'ground_cannon', 'CannonMagic spawns PrefabType.GroundCannon');
INSERT INTO "public"."magic_game_object_aliases" ("magic_name", "game_object_name", "reason") VALUES ('tower', 'ground_tower', 'TowerMagic spawns PrefabType.GroundTower');
INSERT INTO "public"."magic_game_object_aliases" ("magic_name", "game_object_name", "reason") VALUES ('vine_world', 'giant_vine', 'VineWorldMagic spawns PrefabType.GiantVine; vine_world has no game_objects row');
INSERT INTO "public"."magic_game_object_aliases" ("magic_name", "game_object_name", "reason") VALUES ('lightning_explosion', 'electric_explode', 'LightningExplosionMagic spawns PrefabType.ElectricExplode');
INSERT INTO "public"."magic_game_object_aliases" ("magic_name", "game_object_name", "reason") VALUES ('fire_slime_nest', 'fire_summon', 'FireSlimeNestMagic spawns PrefabType.FireSummon');
INSERT INTO "public"."magic_game_object_aliases" ("magic_name", "game_object_name", "reason") VALUES ('lightning_shot', 'electric_shot', 'LightningShotMagic spawns PrefabType.ElectricShot');
INSERT INTO "public"."magic_game_object_aliases" ("magic_name", "game_object_name", "reason") VALUES ('wind_explosion', 'wind_explode', 'WindExplosionMagic spawns PrefabType.WindExplode');
INSERT INTO "public"."magic_game_object_aliases" ("magic_name", "game_object_name", "reason") VALUES ('water_slime_nest', 'pve_water_slime_nest', 'the only water slime nest that exists');


--
-- Data for Name: magic_parameters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."magic_parameters" ("id", "magic_id", "parameter_id", "value", "updated_at") VALUES (1, 47, 24, 3, '2026-09-16 10:06:03.682302');
INSERT INTO "public"."magic_parameters" ("id", "magic_id", "parameter_id", "value", "updated_at") VALUES (2, 84, 24, 3, '2026-09-16 10:06:03.682302');
INSERT INTO "public"."magic_parameters" ("id", "magic_id", "parameter_id", "value", "updated_at") VALUES (3, 68, 24, 3, '2026-09-16 10:06:03.682302');
INSERT INTO "public"."magic_parameters" ("id", "magic_id", "parameter_id", "value", "updated_at") VALUES (4, 31, 24, 3, '2026-09-16 10:06:03.682302');
INSERT INTO "public"."magic_parameters" ("id", "magic_id", "parameter_id", "value", "updated_at") VALUES (5, 5, 24, 3, '2026-09-16 10:06:03.682302');
INSERT INTO "public"."magic_parameters" ("id", "magic_id", "parameter_id", "value", "updated_at") VALUES (6, 64, 24, 3, '2026-09-16 10:06:03.682302');
INSERT INTO "public"."magic_parameters" ("id", "magic_id", "parameter_id", "value", "updated_at") VALUES (7, 78, 24, 0, '2026-09-16 10:06:03.682302');
INSERT INTO "public"."magic_parameters" ("id", "magic_id", "parameter_id", "value", "updated_at") VALUES (8, 26, 24, 0, '2026-09-16 10:06:03.682302');
INSERT INTO "public"."magic_parameters" ("id", "magic_id", "parameter_id", "value", "updated_at") VALUES (9, 35, 24, 0, '2026-09-16 10:06:03.682302');
INSERT INTO "public"."magic_parameters" ("id", "magic_id", "parameter_id", "value", "updated_at") VALUES (10, 46, 24, 3, '2026-09-16 10:06:03.682302');
INSERT INTO "public"."magic_parameters" ("id", "magic_id", "parameter_id", "value", "updated_at") VALUES (11, 25, 24, 0, '2026-09-16 10:06:03.682302');


--
-- Data for Name: magic_tags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (68, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (67, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (66, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (65, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (64, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (63, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (62, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (61, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (59, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (58, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (57, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (56, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (55, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (54, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (52, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (51, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (50, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (49, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (48, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (46, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (43, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (41, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (40, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (39, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (35, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (32, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (31, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (30, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (29, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (28, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (27, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (21, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (20, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (19, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (18, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (17, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (16, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (12, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (11, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (9, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (8, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (7, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (6, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (5, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (68, 2);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (58, 2);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (55, 2);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (51, 2);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (49, 2);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (32, 2);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (31, 2);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (28, 2);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (5, 2);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (68, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (66, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (64, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (63, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (62, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (52, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (51, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (50, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (40, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (39, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (32, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (31, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (28, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (21, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (17, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (16, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (12, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (11, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (9, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (7, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (6, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (68, 4);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (64, 4);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (46, 4);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (32, 4);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (31, 4);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (5, 4);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (67, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (63, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (61, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (59, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (57, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (56, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (54, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (51, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (43, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (41, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (40, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (39, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (35, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (32, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (20, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (19, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (16, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (9, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (8, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (66, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (63, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (62, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (57, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (52, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (50, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (40, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (27, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (18, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (17, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (16, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (44, 7);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (46, 9);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (30, 9);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (65, 10);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (64, 10);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (48, 10);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (39, 10);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (29, 10);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (55, 11);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (30, 11);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (48, 12);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (39, 12);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (29, 12);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (58, 13);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (49, 13);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (46, 13);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (43, 13);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (41, 13);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (32, 13);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (18, 13);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (8, 13);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (70, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (70, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (23, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (23, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (24, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (24, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (10, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (10, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (5, 11);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (5, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (47, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (15, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (3, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (25, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (14, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (36, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (60, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (45, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (2, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (4, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (1, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (26, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (47, 2);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (3, 2);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (2, 2);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (4, 2);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (1, 2);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (15, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (25, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (45, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (26, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (47, 4);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (25, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (36, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (60, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (26, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (15, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (25, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (14, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (26, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (47, 11);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (36, 13);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (69, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (69, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (69, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (69, 10);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (3, 11);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (1, 11);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (4, 11);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (2, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (71, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (71, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (71, 10);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (71, 13);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (72, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (72, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (72, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (72, 10);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (73, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (73, 9);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (73, 11);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (74, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (74, 10);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (74, 11);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (74, 12);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (75, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (75, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (75, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (75, 13);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (76, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (76, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (77, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (77, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (77, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (78, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (78, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (78, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (78, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (79, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (79, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (79, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (80, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (80, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (80, 6);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (80, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (81, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (81, 7);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (82, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (82, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (82, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (83, 13);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (83, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (83, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (84, 5);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (84, 3);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (84, 4);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (84, 1);
INSERT INTO "public"."magic_tags" ("magic_id", "tag_id") VALUES (44, 5);


--
-- Data for Name: magics; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (7, 'fire_shot', 'DEFAULT', 'Fire', '2026-09-16 10:06:03.327805', NULL, NULL, 'Shot', 'fire_shot', '{"layers": [{"end": "target", "shape": "lane", "origin": "caster", "halfWidth": {"object": "fire_shot", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": 1, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (9, 'chain_lightning', 'DEFAULT', 'Lightning', '2026-09-16 10:06:03.327805', NULL, NULL, 'Shot', 'chain_lightning', '{"layers": [{"end": "target", "shape": "lane", "origin": "caster", "halfWidth": {"object": "chain_lightning", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "chain_lightning", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (23, 'frenzy_totem', 'DEFAULT', 'Fire', '2026-09-16 10:06:03.327805', NULL, NULL, 'Drop', 'frenzy_totem', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "frenzy_totem", "parameter": "attack_range"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (14, 'fire_slime_nest', 'DEFAULT', 'None', '2026-09-16 10:06:03.327805', NULL, NULL, 'Summon', 'fire_summon', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "fire_summon", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (40, 'healing_totem', 'DEFAULT', 'Water', '2026-09-16 10:06:03.327805', NULL, NULL, 'Summon', 'healing_totem', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "healing_totem", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "healing_totem", "parameter": "effect_radius"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (25, 'cannon', 'DEFAULT', 'Rock', '2026-09-16 10:06:03.327805', NULL, NULL, 'Code', 'ground_cannon', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "ground_cannon", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "ground_cannon", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (28, 'aqua_archer', 'DEFAULT', 'Water', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'aqua_archer', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "aqua_archer", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "aqua_archer", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (32, 'fire_spirit', 'DEFAULT', 'Fire', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'fire_spirit', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "fire_spirit", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "fire_spirit", "parameter": "sub_attack_range"}, "edgeWidth": 0.08}, {"shape": "circle", "origin": "target", "radius": {"object": "fire_spirit", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (46, 'cloud_dragon', 'DEFAULT', 'Water', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'cloud_dragon', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "cloud_dragon", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "cloud_dragon", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (1, 'ember_spirit_swarm', 'DEFAULT', 'Fire', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'fire_slime', '{"layers": [{"shape": "circle", "origin": "target", "radius": 1}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (45, 'lightning_shot', 'DEFAULT', 'None', '2026-09-16 10:06:03.327805', NULL, NULL, 'Shot', 'electric_shot', '{"layers": [{"end": "target", "shape": "lane", "origin": "caster", "halfWidth": {"object": "electric_shot", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": 1, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (19, 'magma_explosion', 'DEFAULT', 'Fire', '2026-09-16 10:06:03.327805', NULL, NULL, 'Explosion', 'magma_explosion', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "magma_explosion", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (24, 'leafair', 'DEFAULT', 'Nature', '2026-09-16 10:06:03.327805', NULL, NULL, 'Drop', 'leafair', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "leaf_drop", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (35, 'lightning_drop', 'DEFAULT', 'Lightning', '2026-09-16 10:06:03.327805', NULL, NULL, 'Drop', 'lightning_cloud', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "lightning_drop", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (44, 'meteor_shower', 'DEFAULT', 'Fire', '2026-09-16 10:06:03.327805', NULL, NULL, 'Drop', 'meteor_shower', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "meteor_shower", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (55, 'chicken_commando', 'DEFAULT', 'Wind', '2026-09-16 10:06:03.327805', NULL, NULL, 'Code', NULL, '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "chicken_commando", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (16, 'life_tree', 'DEFAULT', 'Nature', '2026-09-16 10:06:03.327805', NULL, NULL, 'Summon', 'life_tree', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "life_tree", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "life_tree", "parameter": "effect_radius"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (27, 'mana_well', 'DEFAULT', 'Lightning', '2026-09-16 10:06:03.327805', NULL, NULL, 'Summon', 'mana_well', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "mana_well", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (62, 'bubble_generator', 'DEFAULT', 'Water', '2026-09-16 10:06:03.327805', NULL, NULL, 'Summon', 'bubble_generator', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "bubble_generator", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "bubble_generator", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (57, 'crater', 'DEFAULT', 'Fire', '2026-09-16 10:06:03.327805', NULL, NULL, 'Summon', 'crater', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "crater", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "crater_ember", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (8, 'tide_call', 'DEFAULT', 'Water', '2026-09-16 10:06:03.327805', NULL, NULL, 'Shot', 'tide_call', '{"layers": [{"end": "target", "shape": "lane", "origin": "caster", "halfWidth": {"object": "tide_call", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (67, 'shock_overload', 'DEFAULT', 'Lightning', '2026-09-16 10:06:03.327805', NULL, NULL, 'Explosion', 'shock_overload', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "shock_overload", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (69, 'vine_world', 'DEFAULT', 'Nature', '2026-09-16 10:06:03.327805', NULL, NULL, 'Code', NULL, '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "giant_vine", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": 4, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (15, 'water_slime_nest', 'DEFAULT', 'None', '2026-09-16 10:06:03.327805', NULL, NULL, 'Code', NULL, '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "pve_water_slime_nest", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (6, 'water_shot', 'DEFAULT', 'None', '2026-09-16 10:06:03.327805', NULL, NULL, 'Shot', 'water_shot', '{"layers": [{"end": "target", "shape": "lane", "origin": "caster", "halfWidth": {"object": "water_shot", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": 1, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (11, 'rock_rolling', 'DEFAULT', 'Rock', '2026-09-16 10:06:03.327805', NULL, NULL, 'Shot', 'rock_rolling', '{"layers": [{"end": "target", "shape": "lane", "origin": "caster", "halfWidth": {"object": "rock_rolling", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (12, 'wind_blade', 'DEFAULT', 'Wind', '2026-09-16 10:06:03.327805', NULL, NULL, 'Code', 'wind_blade', '{"layers": [{"end": "target", "shape": "lane", "origin": "caster", "halfWidth": {"object": "wind_blade", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (21, 'will_o_wisp', 'DEFAULT', 'Fire', '2026-09-16 10:06:03.327805', NULL, NULL, 'Code', NULL, '{"layers": [{"end": "target", "shape": "lane", "origin": "caster", "halfWidth": {"object": "will_o_wisp", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (10, 'vine_toss', 'DEFAULT', 'Nature', '2026-09-16 10:06:03.327805', NULL, NULL, 'Code', NULL, '{"layers": [{"end": "target", "shape": "lane", "length": 6, "origin": "caster", "halfWidth": {"object": "vine", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (83, 'boulder_strike', 'DEFAULT', 'Rock', '2026-09-16 10:06:03.586433', NULL, NULL, 'Shot', 'boulder_strike', '{"layers": [{"end": "target", "shape": "lane", "origin": "caster", "halfWidth": {"object": "boulder_strike", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (81, 'spirit_bomb', 'DEFAULT', 'Lightning', '2026-09-16 10:06:03.586433', NULL, NULL, 'Code', NULL, '{"layers": [{"end": "aim", "shape": "lane", "origin": "caster", "halfWidth": 0.75}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (82, 'tidal_warhead', 'DEFAULT', 'Water', '2026-09-16 10:06:03.586433', NULL, NULL, 'Code', NULL, '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "tidal_warhead", "parameter": "radius"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (20, 'water_explosion', 'DEFAULT', 'Water', '2026-09-16 10:06:03.327805', NULL, NULL, 'Explosion', 'water_explosion', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "water_explosion", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (36, 'wind_explosion', 'DEFAULT', 'None', '2026-09-16 10:06:03.327805', NULL, NULL, 'Code', 'wind_explode', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "wind_explode", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (60, 'lightning_explosion', 'DEFAULT', 'Lightning', '2026-09-16 10:06:03.327805', NULL, NULL, 'Explosion', 'electric_explode', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "electric_explode", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (41, 'sand_storm', 'DEFAULT', 'Rock', '2026-09-16 10:06:03.327805', NULL, NULL, 'Explosion', 'sand_storm', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "sand_storm", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (56, 'overgrowth', 'DEFAULT', 'Nature', '2026-09-16 10:06:03.327805', NULL, NULL, 'Explosion', 'overgrowth', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "overgrowth", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (61, 'razor_gale', 'DEFAULT', 'Wind', '2026-09-16 10:06:03.327805', NULL, NULL, 'Explosion', 'razor_gale', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "razor_gale", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (43, 'tornado_strike', 'DEFAULT', 'Wind', '2026-09-16 10:06:03.327805', NULL, NULL, 'Explosion', 'tornado_strike', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "tornado_strike", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (54, 'rock_drop', 'DEFAULT', 'Rock', '2026-09-16 10:06:03.327805', NULL, NULL, 'Drop', 'rock_drop', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "rock_drop", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (52, 'pve_nature_slime_nest', 'DEFAULT', 'None', '2026-09-16 10:06:03.327805', NULL, NULL, 'Code', NULL, '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "pve_nature_slime_nest", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (70, 'seed_nest', 'DEFAULT', 'Nature', '2026-09-16 10:06:03.327805', NULL, NULL, 'Summon', 'seed_nest', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "seed_nest", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (59, 'rallying_totem', 'DEFAULT', 'Fire', '2026-09-16 10:06:03.327805', NULL, NULL, 'Summon', 'rallying_totem', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "rallying_totem", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (17, 'rock_turret', 'DEFAULT', 'Rock', '2026-09-16 10:06:03.327805', NULL, NULL, 'Summon', 'rock_turret', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "rock_turret", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "rock_turret", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (26, 'tower', 'DEFAULT', 'Rock', '2026-09-16 10:06:03.327805', NULL, NULL, 'Code', 'ground_tower', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "ground_tower", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "ground_tower", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (80, 'titan_remnant', 'DEFAULT', 'Rock', '2026-09-16 10:06:03.586433', NULL, NULL, 'Summon', 'titan_remnant', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "titan_remnant", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "titan_remnant", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (66, 'towerback', 'DEFAULT', 'Rock', '2026-09-16 10:06:03.327805', NULL, NULL, 'Summon', 'towerback', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "towerback", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "towerback", "parameter": "sub_attack_range"}, "edgeWidth": 0.08}, {"shape": "circle", "origin": "target", "radius": {"object": "towerback", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (63, 'electric_tower', 'DEFAULT', 'Lightning', '2026-09-16 10:06:03.327805', NULL, NULL, 'Summon', 'electric_tower', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "electric_tower", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "electric_tower", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (50, 'vine_colony', 'DEFAULT', 'Nature', '2026-09-16 10:06:03.327805', NULL, NULL, 'Summon', 'vine_colony', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "vine_colony", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "vine_colony", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (18, 'wind_totem', 'DEFAULT', 'Wind', '2026-09-16 10:06:03.327805', NULL, NULL, 'Summon', 'wind_totem', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "wind_totem", "parameter": "radius"}}, {"end": "forward", "shape": "lane", "length": {"object": "wind_totem", "parameter": "push_range_x"}, "origin": "target", "halfWidth": 1.5}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (78, 'dragon_tower', 'DEFAULT', 'Fire', '2026-09-16 10:06:03.531772', NULL, NULL, 'Summon', 'dragon_tower', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "dragon_tower", "parameter": "radius"}}, {"end": "forward", "shape": "lane", "length": {"object": "dragon_tower", "parameter": "attack_range"}, "origin": "target", "halfWidth": {"object": "dragon_flame", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (79, 'firework_tower', 'DEFAULT', 'Fire', '2026-09-16 10:06:03.55465', NULL, NULL, 'Summon', 'firework_tower', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "firework_tower", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "firework_tower", "parameter": "attack_range"}, "edgeWidth": 0.08, "forwardOffset": {"object": "firework_tower", "parameter": "attack_offset"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (76, 'repair_totem', 'DEFAULT', 'Nature', '2026-09-16 10:06:03.491999', NULL, NULL, 'Summon', 'repair_totem', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "repair_totem", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "repair_totem", "parameter": "effect_radius"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (77, 'grass_generator', 'DEFAULT', 'Nature', '2026-09-16 10:06:03.514302', NULL, NULL, 'Summon', 'grass_generator', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "grass_generator", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "grass_generator", "parameter": "effect_radius"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (75, 'shock_trap', 'DEFAULT', 'Lightning', '2026-09-16 10:06:03.476526', NULL, NULL, 'Summon', 'shock_trap', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "shock_trap", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "shock_trap", "parameter": "effect_radius"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (71, 'evil_ent', 'DEFAULT', 'Nature', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'evil_ent', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "evil_ent", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "evil_ent", "parameter": "attack_range"}, "edgeWidth": 0.08}, {"shape": "circle", "origin": "target", "radius": {"object": "evil_ent", "parameter": "sub_attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (73, 'storm_stag', 'DEFAULT', 'Lightning', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'storm_stag', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "storm_stag", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (29, 'rock_golem', 'DEFAULT', 'Rock', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'rock_golem', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "rock_golem", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (30, 'storm_rider', 'DEFAULT', 'Water', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'storm_rider', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "storm_rider", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (48, 'tree_golem', 'DEFAULT', 'Nature', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'tree_golem', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "tree_golem", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (74, 'wall_golem', 'DEFAULT', 'Rock', '2026-09-16 10:06:03.45581', NULL, NULL, 'Spawn', 'wall_golem', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "wall_golem", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (64, 'fire_lord_spirit', 'DEFAULT', 'Fire', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'fire_lord_spirit', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "fire_lord_spirit", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (65, 'dimension_toad', 'DEFAULT', 'Fire', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'dimension_toad', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "dimension_toad", "parameter": "radius"}}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (58, 'zap_mouse', 'DEFAULT', 'Lightning', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'zap_mouse', '{"layers": [{"shape": "circle", "origin": "target", "radius": 1}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (5, 'wind_spirit', 'DEFAULT', 'Wind', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'wind_spirit', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "wind_spirit", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "wind_spirit", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (31, 'thunder_spirit', 'DEFAULT', 'Lightning', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'thunder_spirit', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "thunder_spirit", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "thunder_spirit", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (39, 'magma_spirit', 'DEFAULT', 'Fire', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'magma_spirit', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "magma_spirit", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "magma_spirit", "parameter": "sub_attack_range"}, "edgeWidth": 0.08}, {"shape": "circle", "origin": "target", "radius": {"object": "magma_spirit", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (51, 'rock_mage', 'DEFAULT', 'Rock', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'rock_mage', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "rock_mage", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "rock_mage", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (68, 'bubble_spirit', 'DEFAULT', 'Water', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'bubble_spirit', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "bubble_spirit", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "bubble_spirit", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (72, 'sea_serpent', 'DEFAULT', 'Water', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'sea_serpent', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "sea_serpent", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "sea_serpent", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (84, 'bomb_sprite', 'DEFAULT', 'Wind', '2026-09-16 10:06:03.586433', NULL, NULL, 'Spawn', 'bomb_sprite', '{"layers": [{"shape": "circle", "origin": "target", "radius": {"object": "bomb_sprite", "parameter": "radius"}}, {"shape": "circle", "origin": "target", "radius": {"object": "bomb_sprite", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (3, 'mini_rock_swarm', 'DEFAULT', 'Rock', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'mini_rock', '{"layers": [{"shape": "circle", "origin": "target", "radius": 1}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (4, 'seed_spirit_swarm', 'DEFAULT', 'Nature', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'seed_spirit', '{"layers": [{"shape": "circle", "origin": "target", "radius": 1}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (2, 'water_slime_swarm', 'DEFAULT', 'Water', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'water_slime', '{"layers": [{"shape": "circle", "origin": "target", "radius": 1}, {"shape": "circle", "origin": "target", "radius": {"object": "aqua_archer", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (47, 'thunder_bird_swarm', 'DEFAULT', 'Lightning', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'thunder_bird', '{"layers": [{"shape": "circle", "origin": "target", "radius": 1}, {"shape": "circle", "origin": "target", "radius": {"object": "thunder_bird", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');
INSERT INTO "public"."magics" ("id", "name", "access_type", "element", "updated_at", "unlock_condition_type", "unlock_required_value", "cast_kind", "prefab", "indicator") VALUES (49, 'vine_spirit', 'DEFAULT', 'Nature', '2026-09-16 10:06:03.327805', NULL, NULL, 'Spawn', 'vine_spirit', '{"layers": [{"shape": "circle", "origin": "target", "radius": 1}, {"shape": "circle", "origin": "target", "radius": {"object": "vine_spirit", "parameter": "attack_range"}, "edgeWidth": 0.08}], "version": 1}');


--
-- Data for Name: parameter_values; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (882, 4, 218, 500, '2026-09-16 10:06:03.206031');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (900, 76, 220, 1.5, '2026-09-16 10:06:03.235809');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (902, 2, 220, 150, '2026-09-16 10:06:03.235809');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (904, 4, 220, 300, '2026-09-16 10:06:03.235809');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (14, 7, 7, 1, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (15, 7, 8, 2, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (16, 7, 9, 3, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (17, 7, 10, 4, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (19, 7, 12, 6, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (20, 7, 13, 7, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (21, 7, 14, 8, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (22, 7, 15, 9, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (23, 7, 16, 10, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (24, 7, 17, 11, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (25, 7, 18, 12, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (27, 7, 20, 14, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (28, 7, 21, 15, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (32, 7, 25, 19, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (33, 7, 26, 20, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (34, 7, 27, 21, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (36, 7, 29, 23, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (37, 7, 30, 24, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (38, 7, 31, 25, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (39, 7, 32, 26, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (47, 7, 40, 35, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (48, 7, 41, 36, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (55, 7, 48, 43, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (56, 7, 49, 44, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (57, 7, 50, 45, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (59, 7, 52, 47, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (64, 7, 57, 52, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (66, 7, 59, 54, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (68, 7, 61, 56, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (72, 7, 65, 60, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (79, 7, 72, 67, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (167, 8, 73, 1.2, '2026-09-16 10:06:02.444033');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (163, 2, 73, 100, '2026-09-16 10:06:02.444033');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (335, 8, 34, 2, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (336, 10, 34, 5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (41, 7, 34, 28, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (340, 5, 34, 2, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (341, 9, 34, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (342, 3, 34, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (343, 1, 34, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (113, 8, 67, 1.2, '2026-09-16 10:06:02.389989');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (114, 10, 67, 2.5, '2026-09-16 10:06:02.389989');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (112, 6, 67, 12, '2026-09-16 10:06:02.389989');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (347, 41, 67, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (348, 42, 67, 4, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (267, 28, 67, 8, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (109, 3, 67, 0.65, '2026-09-16 10:06:02.389989');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (168, 10, 73, 4.5, '2026-09-16 10:06:02.444033');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (166, 5, 73, 1, '2026-09-16 10:06:02.444033');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (266, 28, 73, 8, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (337, 2, 34, 100, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (338, 4, 34, 300, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (110, 4, 67, 180, '2026-09-16 10:06:02.389989');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (165, 4, 73, 180, '2026-09-16 10:06:02.444033');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (111, 5, 67, 1000000, '2026-09-16 10:06:02.389989');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (74, 7, 67, 62, '2026-09-16 10:06:03.670339');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (80, 7, 73, 68, '2026-09-16 10:06:03.670339');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (164, 3, 73, 0.45, '2026-09-16 10:06:02.444033');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (162, 1, 73, 0.7, '2026-09-16 10:06:02.444033');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (197, 9, 79, 5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (364, 49, 5, 20, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (6, 3, 5, 0.5, '2026-09-16 10:06:02.206153');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (366, 60, 5, 6, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (367, 1, 5, NULL, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (368, 10, 15, 4, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (83, 2, 60, 30, '2026-09-16 10:06:02.307733');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (371, 3, 15, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (373, 1, 15, 5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (81, 8, 60, 1.2, '2026-09-16 10:06:02.307733');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (185, 20, 60, 3, '2026-09-16 10:06:02.51073');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (86, 5, 60, 1, '2026-09-16 10:06:02.307733');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (84, 3, 60, 0.45, '2026-09-16 10:06:02.307733');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (186, 24, 60, 10, '2026-09-16 10:06:02.51073');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (82, 1, 60, 0.75, '2026-09-16 10:06:02.307733');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (384, 10, 51, 5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (58, 7, 51, 46, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (388, 5, 51, 3, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (389, 9, 51, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (390, 3, 51, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (391, 1, 51, 0.6, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (95, 6, 62, 40, '2026-09-16 10:06:02.334805');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (92, 3, 62, 0.75, '2026-09-16 10:06:02.334805');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (400, 7, 74, NULL, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (91, 3, 74, 0.35, '2026-09-16 10:06:02.334805');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (143, 8, 70, 1.1, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (144, 11, 70, 5.5, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (142, 5, 70, 2.2, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (145, 12, 70, 4, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (140, 3, 70, 0.65, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (138, 1, 70, 0.65, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (412, 49, 116, 10, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (413, 3, 116, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (277, 3, 92, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (307, 6, 104, 3, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (288, 3, 104, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (253, 3, 87, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (265, 1, 87, 8, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (244, 8, 83, 1, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (204, 5, 83, 1, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (212, 3, 83, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (228, 1, 83, 0.8, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (283, 3, 99, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (123, 8, 68, 1, '2026-09-16 10:06:02.401889');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (124, 10, 68, 5, '2026-09-16 10:06:02.401889');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (116, 14, 68, 2, '2026-09-16 10:06:02.401889');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (117, 15, 68, 2, '2026-09-16 10:06:02.401889');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (122, 6, 68, 20, '2026-09-16 10:06:02.401889');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (119, 3, 68, 0.65, '2026-09-16 10:06:02.401889');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (240, 8, 79, 2, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (200, 5, 79, 1, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (208, 3, 79, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (224, 1, 79, 0.8, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (449, 49, 3, 10, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (7, 3, 3, 1.5, '2026-09-16 10:06:02.206153');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (451, 60, 3, 9, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (13, 6, 6, 3, '2026-09-16 10:06:02.206153');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (5, 3, 6, 0.5, '2026-09-16 10:06:02.206153');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (454, 6, 126, 1.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (455, 3, 126, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (456, 49, 127, 10, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (457, 60, 127, 0, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (136, 8, 75, 1, '2026-09-16 10:06:02.414741');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (137, 10, 75, 4, '2026-09-16 10:06:02.414741');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (135, 5, 75, 1, '2026-09-16 10:06:02.414741');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (133, 3, 75, 0.35, '2026-09-16 10:06:02.414741');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (131, 1, 75, 0.8, '2026-09-16 10:06:02.414741');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (279, 3, 94, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (273, 3, 88, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (305, 6, 102, 3, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (286, 3, 102, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (130, 8, 69, 1.6, '2026-09-16 10:06:02.414741');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (129, 5, 69, 3, '2026-09-16 10:06:02.414741');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (127, 3, 69, 0.9, '2026-09-16 10:06:02.414741');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (125, 1, 69, 0.45, '2026-09-16 10:06:02.414741');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (249, 3, 13, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (262, 1, 13, 8, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (414, 60, 116, 14, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (383, 8, 51, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (369, 2, 15, 100, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (121, 5, 68, 1000000, '2026-09-16 10:06:02.401889');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (94, 5, 62, 1000000, '2026-09-16 10:06:02.334805');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (372, 60, 15, 18, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (67, 7, 60, 55, '2026-09-16 10:06:03.670339');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (69, 7, 62, 57, '2026-09-16 10:06:03.670339');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (77, 7, 70, 65, '2026-09-16 10:06:03.670339');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (75, 7, 68, 63, '2026-09-16 10:06:03.670339');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (76, 7, 69, 64, '2026-09-16 10:06:03.670339');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (243, 8, 82, 1, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (194, 6, 77, 20, '2026-09-16 10:06:02.51073');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (524, 10, 78, 6, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (203, 5, 82, 1, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (211, 3, 82, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (227, 1, 82, 0.8, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (318, 8, 38, 1, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (319, 10, 38, 1.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (193, 6, 76, 20, '2026-09-16 10:06:02.51073');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (326, 10, 44, 2, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (45, 7, 38, 32, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (313, 5, 38, 1, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (493, 9, 38, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (314, 3, 38, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (316, 1, 38, 0.6, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (496, 30, 38, 1.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (282, 3, 98, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (156, 8, 77, 0.8, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (158, 11, 77, 4.5, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (154, 5, 77, 0.8, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (160, 12, 77, 3, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (150, 3, 77, 0.3, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (146, 1, 77, 1.15, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (173, 10, 29, 1.5, '2026-09-16 10:06:02.474491');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (170, 17, 29, 10, '2026-09-16 10:06:02.474491');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (172, 3, 29, 0.5, '2026-09-16 10:06:02.474491');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (171, 1, 29, 5, '2026-09-16 10:06:02.474491');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (512, 37, 139, 10, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (513, 6, 139, 300000, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (514, 44, 139, 30000, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (515, 8, 140, 3, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (516, 10, 140, 6, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (519, 7, 140, 25, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (521, 9, 140, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (522, 3, 140, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (523, 8, 78, 3, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (196, 6, 78, 60, '2026-09-16 10:06:02.51073');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (528, 7, 78, 26, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (530, 9, 78, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (531, 3, 78, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (532, 8, 45, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (534, 6, 45, 30, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (52, 7, 45, 40, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (538, 9, 45, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (539, 3, 45, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (254, 3, 96, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (275, 3, 90, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (308, 6, 105, 3, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (289, 3, 105, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (245, 8, 84, 1, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (205, 5, 84, 1, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (213, 3, 84, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (229, 1, 84, 0.8, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (553, 8, 22, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (555, 6, 22, 8, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (29, 7, 22, 16, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (559, 9, 22, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (560, 3, 22, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (562, 49, 148, 10, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (563, 60, 148, 0, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (269, 3, 40, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (157, 8, 76, 0.7, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (159, 11, 76, 5, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (155, 5, 76, 0.75, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (161, 12, 76, 3.5, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (151, 3, 76, 0.3, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (147, 1, 76, 1.25, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (268, 3, 25, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (578, 6, 152, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (579, 3, 152, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (325, 8, 44, 3, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (51, 7, 44, 39, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (320, 5, 44, 10, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (586, 9, 44, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (321, 3, 44, 1.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (323, 1, 44, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (589, 30, 44, 1.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (590, 8, 33, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (40, 7, 33, 27, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (594, 9, 33, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (595, 3, 33, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (597, 3, 155, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (598, 8, 49, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (599, 37, 49, 25, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (600, 6, 49, 6, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (520, 5, 140, 1000000, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (529, 5, 78, 1000000, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (537, 5, 45, 1000000, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (558, 5, 22, 1000000, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (540, 60, 45, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (561, 60, 22, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (601, 3, 49, 3, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (602, 8, 157, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (198, 9, 80, 4, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (605, 7, 157, 3, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (606, 5, 157, 3, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (607, 9, 157, 2, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (608, 3, 157, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (609, 1, 157, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (610, 49, 158, 10, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (611, 60, 158, 0, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (280, 3, 95, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (87, 9, 61, 2, '2026-09-16 10:06:02.319703');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (88, 3, 61, 1.5, '2026-09-16 10:06:02.319703');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (617, 51, 161, 120, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (620, 3, 57, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (623, 3, 163, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (626, 3, 164, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (176, 17, 64, 10, '2026-09-16 10:06:02.485379');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (175, 6, 64, 10, '2026-09-16 10:06:02.485379');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (71, 7, 64, 59, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (174, 3, 64, 0.6, '2026-09-16 10:06:02.485379');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (108, 8, 66, 0.5, '2026-09-16 10:06:02.379412');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (107, 6, 66, 3, '2026-09-16 10:06:02.379412');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (106, 3, 66, 2.5, '2026-09-16 10:06:02.379412');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (636, 49, 167, 10, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (637, 60, 167, 0, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (271, 3, 59, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (276, 3, 91, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (642, 8, 35, 2.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (42, 7, 35, 29, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (646, 5, 35, 10, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (647, 9, 35, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (648, 3, 35, 1.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (649, 1, 35, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (650, 8, 56, 2, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (651, 10, 56, 4, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (652, 37, 56, 2, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (63, 7, 56, 51, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (656, 5, 56, 2, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (657, 9, 56, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (658, 3, 56, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (659, 1, 56, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (250, 3, 17, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (263, 1, 17, 2, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (246, 8, 85, 1, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (206, 5, 85, 1, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (214, 3, 85, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (230, 1, 85, 0.8, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (284, 3, 100, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (671, 8, 23, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (672, 10, 23, 3, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (30, 7, 23, 17, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (677, 9, 23, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (678, 3, 23, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (679, 10, 176, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (681, 3, 176, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (304, 6, 46, 5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (53, 7, 46, 41, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (685, 9, 46, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (270, 3, 46, 2, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (241, 8, 80, 1, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (201, 5, 80, 1, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (209, 3, 80, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (225, 1, 80, 0.8, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (272, 3, 72, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (697, 49, 2, 15, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (8, 3, 2, 0.5, '2026-09-16 10:06:02.206153');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (699, 60, 2, 18, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (700, 1, 2, 10, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (701, 8, 1, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (12, 5, 1, 1, '2026-09-16 10:06:02.206153');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (706, 9, 1, 10, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (9, 3, 1, 0.2, '2026-09-16 10:06:02.206153');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1, 1, 1, 0.8, '2026-09-16 10:06:02.206153');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (709, 49, 4, 15, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (710, 60, 4, 6, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (711, 8, 36, 0.7, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (43, 7, 36, 30, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (715, 5, 36, 2, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (716, 9, 36, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (717, 3, 36, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (718, 1, 36, 3, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (719, 8, 184, 3, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (720, 10, 184, 4, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (625, 5, 164, 1000000, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (619, 5, 57, 1000000, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (676, 5, 23, 1000000, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (622, 5, 163, 1000000, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (73, 7, 66, 61, '2026-09-16 10:06:03.670339');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (724, 5, 184, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (725, 9, 184, 3, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (726, 3, 184, 0.3, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (727, 1, 184, 1.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (728, 8, 37, 2, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (729, 10, 37, 4, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (44, 7, 37, 31, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (733, 5, 37, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (734, 9, 37, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (735, 3, 37, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (736, 1, 37, 2, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (334, 6, 14, 4, '2026-09-16 10:06:02.602542');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (333, 3, 14, 2, '2026-09-16 10:06:02.602542');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (331, 1, 14, 3, '2026-09-16 10:06:02.602542');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (741, 8, 48, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (743, 6, 48, 6, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (744, 3, 48, 2, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (745, 1, 48, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (183, 8, 71, 1, '2026-09-16 10:06:02.496583');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (184, 10, 71, 5, '2026-09-16 10:06:02.496583');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (180, 3, 71, 0.5, '2026-09-16 10:06:02.496583');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (330, 30, 71, 0.6, '2026-09-16 10:06:02.602542');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (178, 19, 71, 0.325, '2026-09-16 10:06:02.496583');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (756, 8, 53, 2.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (758, 45, 53, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (759, 46, 53, 1.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (60, 7, 53, 48, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (762, 5, 53, 10, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (763, 9, 53, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (764, 3, 53, 1.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (765, 1, 53, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (767, 6, 190, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (768, 3, 190, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (769, 8, 55, 1.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (770, 10, 55, 3, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (62, 7, 55, 50, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (776, 9, 55, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (777, 3, 55, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (778, 8, 54, 1.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (779, 10, 54, 4, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (61, 7, 54, 49, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (783, 5, 54, 2, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (785, 3, 54, 0.8, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (786, 1, 54, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (190, 25, 16, 9, '2026-09-16 10:06:02.51073');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (191, 26, 16, 1, '2026-09-16 10:06:02.51073');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (192, 27, 16, 0.12, '2026-09-16 10:06:02.51073');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (790, 49, 194, 10, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (791, 60, 194, 0, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (274, 3, 89, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (327, 3, 26, 1.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (329, 29, 26, 10, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (306, 6, 103, 3, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (287, 3, 103, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (248, 3, 12, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (261, 1, 12, 8, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (242, 8, 81, 1, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (202, 5, 81, 1, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (210, 3, 81, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (226, 1, 81, 0.8, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (252, 3, 27, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (255, 1, 27, 8, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (812, 49, 201, 10, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (813, 60, 201, 0, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (251, 3, 18, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (264, 1, 18, 8, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (281, 3, 97, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (278, 3, 93, 5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (822, 3, 205, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (247, 8, 86, 1, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (207, 5, 86, 1, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (215, 3, 86, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (231, 1, 86, 0.8, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (829, 8, 11, 3, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (830, 10, 11, 1.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (18, 7, 11, 5, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (834, 5, 11, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (835, 9, 11, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (836, 3, 11, 0.3, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (837, 1, 11, 1.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (285, 3, 101, 0.5, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (840, 8, 24, 1, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (784, 9, 54, 2, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (721, 2, 184, 50, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (182, 5, 71, 1000000, '2026-09-16 10:06:02.496583');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (775, 5, 55, 1000000, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (195, 6, 55, 15, '2026-09-16 10:06:02.51073');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (796, 60, 26, 9, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (78, 7, 71, 66, '2026-09-16 10:06:03.670339');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (723, 7, 184, 47, '2026-09-16 10:06:03.670339');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (31, 7, 24, 18, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (188, 22, 24, 6, '2026-09-16 10:06:02.51073');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (189, 23, 24, 3, '2026-09-16 10:06:02.51073');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (848, 3, 24, 0.5, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (104, 8, 63, 0.8, '2026-09-16 10:06:02.356627');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (97, 11, 63, 6, '2026-09-16 10:06:02.356627');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (260, 2, 87, 20, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (70, 7, 63, 58, '2026-09-16 10:06:02.283643');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (103, 5, 63, 1, '2026-09-16 10:06:02.356627');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (98, 12, 63, 5, '2026-09-16 10:06:02.356627');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (101, 3, 63, 0.35, '2026-09-16 10:06:02.356627');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (99, 1, 63, 1.2, '2026-09-16 10:06:02.356627');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (858, 3, 211, 0.75, '2026-09-16 10:06:02.784318');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (525, 2, 78, 120, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (860, 6, 211, 30, '2026-09-16 10:06:02.784318');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (861, 8, 211, 5, '2026-09-16 10:06:02.784318');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (863, 3, 212, 1.5, '2026-09-16 10:06:02.803749');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (864, 6, 212, 3, '2026-09-16 10:06:02.803749');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (96, 8, 62, 0.25, '2026-09-16 10:06:02.334805');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (89, 10, 74, 2.5, '2026-09-16 10:06:02.334805');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (712, 2, 36, 30, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (199, 9, 81, 3, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (867, 8, 213, 2, '2026-09-16 10:06:02.864224');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (868, 9, 213, 3, '2026-09-16 10:06:02.864224');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (870, 9, 63, 2, '2026-09-16 10:06:02.87378');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (187, 21, 24, 3, '2026-09-16 10:06:02.51073');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (874, 70, 51, 15, '2026-09-16 10:06:02.902942');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (385, 2, 51, 50, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (90, 2, 74, 30, '2026-09-16 10:06:02.334805');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (139, 2, 70, 50, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (411, 2, 116, 100, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (298, 2, 92, 80, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (236, 2, 83, 10, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (118, 2, 68, 50, '2026-09-16 10:06:02.401889');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (232, 2, 79, 10, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (2, 2, 3, 50, '2026-09-16 10:06:02.206153');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (132, 2, 75, 40, '2026-09-16 10:06:02.414741');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (300, 2, 94, 80, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (294, 2, 88, 80, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (126, 2, 69, 80, '2026-09-16 10:06:02.414741');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (257, 2, 13, 100, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (235, 2, 82, 10, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (317, 2, 38, 50, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (148, 2, 77, 30, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (517, 2, 140, 100, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (533, 2, 45, -30, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (302, 2, 96, 80, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (296, 2, 90, 80, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (237, 2, 84, 10, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (554, 2, 22, -30, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (149, 2, 76, 30, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (290, 2, 25, 80, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (577, 2, 152, 110, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (324, 2, 44, 80, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (591, 2, 33, 10, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (596, 2, 155, 200, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (603, 2, 157, 30, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (301, 2, 95, 80, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (614, 2, 61, 20, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (105, 2, 66, 20, '2026-09-16 10:06:02.379412');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (292, 2, 59, 80, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (297, 2, 91, 80, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (643, 2, 35, 50, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (653, 2, 56, 80, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (258, 2, 17, 200, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (238, 2, 85, 10, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (673, 2, 23, 20, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (680, 2, 176, 200, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (682, 2, 46, 20, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (233, 2, 80, 10, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (293, 2, 72, 80, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (3, 2, 2, 150, '2026-09-16 10:06:02.206153');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (4, 2, 1, 10, '2026-09-16 10:06:02.206153');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (730, 2, 37, 50, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (742, 2, 48, 20, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (179, 2, 71, 50, '2026-09-16 10:06:02.496583');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (757, 2, 53, 50, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (766, 2, 190, 90, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (771, 2, 55, 90, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (780, 2, 54, 20, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (295, 2, 89, 80, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (328, 2, 26, 30, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (256, 2, 12, 100, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (234, 2, 81, 10, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (259, 2, 18, 100, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (303, 2, 97, 80, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (299, 2, 93, 0, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (821, 2, 205, 0, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (239, 2, 86, 10, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (831, 2, 11, 300, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (841, 2, 24, 10, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (100, 2, 63, 40, '2026-09-16 10:06:02.356627');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (862, 2, 212, 240, '2026-09-16 10:06:02.803749');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (10, 4, 5, 50, '2026-09-16 10:06:02.206153');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (85, 4, 60, 120, '2026-09-16 10:06:02.307733');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (386, 4, 51, 300, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (93, 4, 62, 150, '2026-09-16 10:06:02.334805');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (141, 4, 70, 320, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (220, 4, 83, 20, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (310, 4, 99, 50, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (120, 4, 68, 160, '2026-09-16 10:06:02.401889');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (134, 4, 75, 90, '2026-09-16 10:06:02.414741');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (128, 4, 69, 450, '2026-09-16 10:06:02.414741');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (219, 4, 82, 20, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (315, 4, 38, 350, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (309, 4, 98, 50, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (518, 4, 140, 450, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (842, 4, 24, 100, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (332, 2, 14, 1, '2026-09-16 10:06:02.602542');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (844, 5, 24, 1000000, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (865, 60, 64, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (291, 2, 40, 30, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (216, 4, 79, 50, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (152, 4, 77, 30, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (527, 4, 78, 400, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (535, 4, 45, 100, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (221, 4, 84, 20, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (556, 4, 22, 100, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (592, 4, 33, 200, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (604, 4, 157, 150, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (618, 4, 57, 1000, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (621, 4, 163, 1500, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (624, 4, 164, 1000, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (644, 4, 35, 1000, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (654, 4, 56, 250, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (222, 4, 85, 20, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (311, 4, 100, 50, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (674, 4, 23, 150, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (11, 4, 1, 20, '2026-09-16 10:06:02.206153');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (713, 4, 36, 220, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (722, 4, 184, 100, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (731, 4, 37, 240, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (181, 4, 71, 180, '2026-09-16 10:06:02.496583');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (760, 4, 53, 300, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (773, 4, 55, 400, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (781, 4, 54, 280, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (218, 4, 81, 20, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (832, 4, 11, 50, '2026-09-16 10:06:02.719012');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (312, 4, 101, 50, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (102, 4, 63, 70, '2026-09-16 10:06:02.356627');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (859, 4, 211, 200, '2026-09-16 10:06:02.784318');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (115, 13, 68, 20, '2026-09-16 10:06:02.401889');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (169, 16, 15, 20, '2026-09-16 10:06:02.464626');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (177, 18, 71, 30, '2026-09-16 10:06:02.496583');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (876, 72, 70, 5, '2026-09-16 10:06:03.008794');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (878, 74, 218, 5, '2026-09-16 10:06:03.206031');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (879, 1, 218, 0.45, '2026-09-16 10:06:03.206031');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (881, 3, 218, 1.2, '2026-09-16 10:06:03.206031');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (883, 5, 218, 10, '2026-09-16 10:06:03.206031');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (884, 8, 218, 1.8, '2026-09-16 10:06:03.206031');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (885, 9, 218, 1, '2026-09-16 10:06:03.206031');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (886, 10, 218, 5, '2026-09-16 10:06:03.206031');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (888, 19, 218, 4, '2026-09-16 10:06:03.206031');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (889, 28, 218, 14, '2026-09-16 10:06:03.206031');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (890, 30, 218, 6, '2026-09-16 10:06:03.206031');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (891, 75, 219, 1, '2026-09-16 10:06:03.221456');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (892, 1, 219, 0.55, '2026-09-16 10:06:03.221456');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (893, 2, 219, 16, '2026-09-16 10:06:03.221456');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (894, 3, 219, 1.2, '2026-09-16 10:06:03.221456');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (895, 4, 219, 160, '2026-09-16 10:06:03.221456');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (896, 5, 219, 10, '2026-09-16 10:06:03.221456');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (897, 8, 219, 3.5, '2026-09-16 10:06:03.221456');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (898, 9, 219, 1, '2026-09-16 10:06:03.221456');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (899, 10, 219, 7, '2026-09-16 10:06:03.221456');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (901, 1, 220, 3, '2026-09-16 10:06:03.235809');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (903, 3, 220, 0.8, '2026-09-16 10:06:03.235809');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (905, 5, 220, 3, '2026-09-16 10:06:03.235809');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (906, 8, 220, 0.8, '2026-09-16 10:06:03.235809');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (907, 9, 220, 1, '2026-09-16 10:06:03.235809');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (908, 11, 220, 5, '2026-09-16 10:06:03.235809');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (909, 12, 220, 2, '2026-09-16 10:06:03.235809');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (912, 5, 101, 1000000, '2026-09-16 10:06:03.25538');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (913, 5, 100, 1000000, '2026-09-16 10:06:03.25538');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (914, 5, 99, 1000000, '2026-09-16 10:06:03.25538');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (915, 5, 98, 1000000, '2026-09-16 10:06:03.25538');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (924, 5, 33, 1000000, '2026-09-16 10:06:03.25538');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (928, 5, 211, 1000000, '2026-09-16 10:06:03.25538');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (929, 5, 212, 1000000, '2026-09-16 10:06:03.25538');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (930, 5, 216, 1000000, '2026-09-16 10:06:03.25538');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (887, 18, 218, 400, '2026-09-16 10:06:03.206031');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (877, 73, 218, 5, '2026-09-16 10:06:03.206031');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (934, 6, 23, 15, '2026-09-16 10:06:03.26387');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (936, 42, 45, 1.5, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (937, 42, 22, 1.5, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (938, 42, 64, 2, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (939, 49, 221, 55, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (940, 49, 220, 60, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (941, 49, 219, 60, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (942, 49, 218, 55, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (943, 49, 64, 30, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (944, 49, 211, 45, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (945, 49, 73, 35, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (153, 4, 76, 30, '2026-09-16 10:06:02.42926');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (947, 49, 71, 45, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (948, 49, 70, 50, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (949, 49, 69, 60, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (950, 49, 68, 30, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (951, 49, 67, 30, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (952, 49, 66, 20, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (953, 49, 65, 20, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (954, 49, 63, 25, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (955, 49, 62, 40, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (956, 49, 61, 20, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (957, 49, 60, 20, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (958, 49, 59, 20, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (217, 4, 80, 50, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (960, 49, 57, 0, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (961, 49, 56, 40, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (962, 49, 55, 40, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (963, 49, 54, 40, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (964, 49, 53, 35, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (965, 49, 52, 35, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (966, 49, 51, 60, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (967, 49, 50, 0, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (968, 49, 49, 50, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (969, 49, 48, 55, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (223, 4, 86, 50, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (971, 49, 46, 20, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (972, 49, 45, 40, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (875, 4, 161, 1000, '2026-09-16 10:06:02.999673');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (880, 2, 218, 90, '2026-09-16 10:06:03.206031');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (973, 49, 44, 55, '2026-09-16 10:06:03.442651');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (322, 4, 44, 1750, '2026-09-16 10:06:02.537553');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (946, 49, 72, 30, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (976, 49, 41, 0, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (977, 49, 40, 20, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (979, 49, 38, 35, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (980, 49, 37, 35, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (981, 49, 36, 35, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (982, 49, 35, 35, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (983, 49, 34, 40, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (984, 49, 33, 40, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (985, 49, 32, 40, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (986, 49, 31, 45, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (987, 49, 30, 20, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (988, 49, 29, 30, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (990, 49, 27, 45, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (991, 49, 26, 20, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (992, 49, 25, 20, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (993, 49, 24, 30, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (994, 49, 23, 30, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (995, 49, 22, 30, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (996, 49, 21, 0, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (997, 49, 20, 0, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (999, 49, 18, 25, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1000, 49, 17, 25, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1001, 49, 16, 25, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1002, 49, 15, 25, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1003, 49, 14, 25, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1004, 49, 13, 25, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1005, 49, 12, 0, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1006, 49, 11, 25, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1007, 49, 10, 25, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1008, 49, 9, 25, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1009, 49, 8, 25, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1010, 49, 7, 25, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1011, 60, 221, 9, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1012, 60, 220, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1013, 60, 219, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1014, 60, 218, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1016, 60, 211, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1017, 60, 73, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1018, 60, 72, 9, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1019, 60, 71, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1020, 60, 70, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1021, 60, 69, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1022, 60, 68, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1023, 60, 67, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1024, 60, 66, 9, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1025, 60, 65, 9, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1026, 60, 63, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1027, 60, 62, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1028, 60, 61, 9, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1029, 60, 60, 14, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1030, 60, 59, 14, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1032, 60, 57, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1033, 60, 56, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1034, 60, 55, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1035, 60, 54, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1036, 60, 53, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1037, 60, 52, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1038, 60, 51, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1039, 60, 50, 18, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1040, 60, 49, 14, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1041, 60, 48, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1043, 60, 46, 9, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1045, 60, 44, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1048, 60, 41, 9, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1049, 60, 40, 14, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1051, 60, 38, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1052, 60, 37, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1053, 60, 36, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1054, 60, 35, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1055, 60, 34, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1056, 60, 33, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1057, 60, 32, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1058, 60, 31, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1059, 60, 30, 14, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1060, 60, 29, 14, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1062, 60, 27, 18, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1064, 60, 25, 9, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1065, 60, 24, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1066, 60, 23, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1068, 60, 21, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1069, 60, 20, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1071, 60, 18, 18, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1072, 60, 17, 18, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1073, 60, 16, 18, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1075, 60, 14, 18, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1076, 60, 13, 18, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1077, 60, 12, 18, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1078, 60, 11, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1079, 60, 10, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1080, 60, 9, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1081, 60, 8, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1082, 60, 7, 6, '2026-09-16 10:06:03.293408');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1156, 1, 222, 0.3, '2026-09-16 10:06:03.45581');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1157, 2, 222, 40, '2026-09-16 10:06:03.45581');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1158, 3, 222, 1.8, '2026-09-16 10:06:03.45581');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1159, 4, 222, 1750, '2026-09-16 10:06:03.45581');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1160, 5, 222, 10, '2026-09-16 10:06:03.45581');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1161, 8, 222, 2.5, '2026-09-16 10:06:03.45581');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1162, 9, 222, 1, '2026-09-16 10:06:03.45581');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1163, 49, 222, 45, '2026-09-16 10:06:03.45581');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1164, 60, 222, 6, '2026-09-16 10:06:03.45581');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1166, 4, 223, 160, '2026-09-16 10:06:03.476526');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1167, 5, 223, 1000000, '2026-09-16 10:06:03.476526');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1168, 6, 223, 20, '2026-09-16 10:06:03.476526');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1169, 8, 223, 8, '2026-09-16 10:06:03.476526');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1170, 49, 223, 40, '2026-09-16 10:06:03.476526');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1171, 60, 223, 6, '2026-09-16 10:06:03.476526');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1172, 78, 223, 1, '2026-09-16 10:06:03.476526');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1175, 4, 224, 100, '2026-09-16 10:06:03.491999');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1176, 5, 224, 1000000, '2026-09-16 10:06:03.491999');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1178, 49, 224, 50, '2026-09-16 10:06:03.491999');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1179, 60, 224, 6, '2026-09-16 10:06:03.491999');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1181, 4, 225, 400, '2026-09-16 10:06:03.514302');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1182, 5, 225, 1000000, '2026-09-16 10:06:03.514302');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1183, 6, 225, 25, '2026-09-16 10:06:03.514302');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1184, 8, 225, 1, '2026-09-16 10:06:03.514302');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1185, 9, 225, 6, '2026-09-16 10:06:03.514302');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1186, 49, 225, 40, '2026-09-16 10:06:03.514302');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1187, 60, 225, 6, '2026-09-16 10:06:03.514302');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1188, 1, 227, 8, '2026-09-16 10:06:03.531772');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1189, 2, 227, 30, '2026-09-16 10:06:03.531772');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1190, 3, 227, 0.5, '2026-09-16 10:06:03.531772');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1191, 3, 226, 1, '2026-09-16 10:06:03.531772');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1192, 4, 226, 400, '2026-09-16 10:06:03.531772');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1193, 5, 226, 1000000, '2026-09-16 10:06:03.531772');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1194, 6, 226, 20, '2026-09-16 10:06:03.531772');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1195, 8, 226, 1.5, '2026-09-16 10:06:03.531772');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1197, 49, 226, 45, '2026-09-16 10:06:03.531772');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1198, 60, 226, 6, '2026-09-16 10:06:03.531772');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1199, 2, 229, 30, '2026-09-16 10:06:03.55465');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1200, 3, 229, 1.5, '2026-09-16 10:06:03.55465');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1201, 4, 228, 150, '2026-09-16 10:06:03.55465');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1202, 5, 228, 1000000, '2026-09-16 10:06:03.55465');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1203, 6, 229, 1, '2026-09-16 10:06:03.55465');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1204, 6, 228, 20, '2026-09-16 10:06:03.55465');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1205, 8, 228, 1, '2026-09-16 10:06:03.55465');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1206, 10, 228, 1.5, '2026-09-16 10:06:03.55465');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1207, 49, 228, 40, '2026-09-16 10:06:03.55465');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1208, 60, 228, 6, '2026-09-16 10:06:03.55465');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1209, 80, 228, 3, '2026-09-16 10:06:03.55465');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1210, 1, 237, 6, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1211, 1, 236, 1.5, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1212, 1, 235, 9, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1213, 1, 233, 7, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1214, 2, 237, 180, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1215, 2, 235, 140, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1216, 2, 233, 240, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1217, 2, 231, 120, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1218, 3, 237, 2, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1219, 3, 236, 0.5, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1220, 3, 235, 0.45, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1221, 3, 233, 2.5, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1173, 79, 223, 10, '2026-09-16 10:06:03.476526');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1180, 3, 225, 1, '2026-09-16 10:06:03.514302');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1174, 3, 224, 0.5, '2026-09-16 10:06:03.491999');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1165, 3, 223, 0.65, '2026-09-16 10:06:03.476526');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1196, 10, 226, 18, '2026-09-16 10:06:03.717963');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1177, 6, 224, 60, '2026-09-16 10:06:03.717963');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1222, 3, 231, 1.25, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1223, 3, 230, 1, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1224, 4, 236, 200, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1225, 4, 230, 400, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1226, 5, 236, 1, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1227, 5, 230, 1000, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1228, 6, 231, 0.8, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1229, 6, 230, 60, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1230, 8, 236, 2.5, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1231, 8, 230, 2, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1232, 9, 236, 1, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1234, 10, 230, 4, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1235, 18, 235, 200, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1236, 21, 235, 7, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1237, 49, 236, 45, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1238, 49, 235, 35, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1240, 49, 232, 50, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1241, 49, 233, 35, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1242, 49, 230, 40, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1243, 60, 230, 6, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1244, 60, 232, 18, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1245, 60, 233, 18, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1246, 60, 235, 18, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1247, 60, 236, 6, '2026-09-16 10:06:03.586433');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1248, 3, 228, 0.75, '2026-09-16 10:06:03.613621');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1249, 42, 223, 3, '2026-09-16 10:06:03.634483');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1250, 42, 224, 4, '2026-09-16 10:06:03.634483');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1251, 42, 225, 5, '2026-09-16 10:06:03.634483');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1255, 7, 79, 1, '2026-09-16 10:06:03.670339');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1256, 7, 80, 4, '2026-09-16 10:06:03.670339');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1257, 7, 81, 2, '2026-09-16 10:06:03.670339');
INSERT INTO "public"."parameter_values" ("id", "parameter_id", "game_object_id", "value", "updated_at") VALUES (1233, 10, 236, 0, '2026-09-16 10:06:03.586433');


--
-- Data for Name: parameters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."parameters" ("id", "name") VALUES (1, 'speed');
INSERT INTO "public"."parameters" ("id", "name") VALUES (2, 'damage');
INSERT INTO "public"."parameters" ("id", "name") VALUES (3, 'radius');
INSERT INTO "public"."parameters" ("id", "name") VALUES (4, 'hp');
INSERT INTO "public"."parameters" ("id", "name") VALUES (5, 'mass');
INSERT INTO "public"."parameters" ("id", "name") VALUES (6, 'duration');
INSERT INTO "public"."parameters" ("id", "name") VALUES (7, 'magic_id');
INSERT INTO "public"."parameters" ("id", "name") VALUES (8, 'attack_interval');
INSERT INTO "public"."parameters" ("id", "name") VALUES (9, 'quantity');
INSERT INTO "public"."parameters" ("id", "name") VALUES (10, 'attack_range');
INSERT INTO "public"."parameters" ("id", "name") VALUES (11, 'detection_range');
INSERT INTO "public"."parameters" ("id", "name") VALUES (12, 'panic_duration');
INSERT INTO "public"."parameters" ("id", "name") VALUES (13, 'chain_damage');
INSERT INTO "public"."parameters" ("id", "name") VALUES (14, 'chain_count');
INSERT INTO "public"."parameters" ("id", "name") VALUES (15, 'chain_radius');
INSERT INTO "public"."parameters" ("id", "name") VALUES (16, 'min_damage');
INSERT INTO "public"."parameters" ("id", "name") VALUES (17, 'buff_duration');
INSERT INTO "public"."parameters" ("id", "name") VALUES (18, 'sub_damage');
INSERT INTO "public"."parameters" ("id", "name") VALUES (19, 'sub_speed');
INSERT INTO "public"."parameters" ("id", "name") VALUES (20, 'fall_gravity');
INSERT INTO "public"."parameters" ("id", "name") VALUES (21, 'push_force');
INSERT INTO "public"."parameters" ("id", "name") VALUES (22, 'push_range_x');
INSERT INTO "public"."parameters" ("id", "name") VALUES (23, 'push_range_y');
INSERT INTO "public"."parameters" ("id", "name") VALUES (24, 'spawn_height');
INSERT INTO "public"."parameters" ("id", "name") VALUES (25, 'vine_count');
INSERT INTO "public"."parameters" ("id", "name") VALUES (26, 'vine_spacing');
INSERT INTO "public"."parameters" ("id", "name") VALUES (27, 'vine_spawn_interval');
INSERT INTO "public"."parameters" ("id", "name") VALUES (28, 'projectile_speed');
INSERT INTO "public"."parameters" ("id", "name") VALUES (29, 'z_force');
INSERT INTO "public"."parameters" ("id", "name") VALUES (30, 'sub_attack_range');
INSERT INTO "public"."parameters" ("id", "name") VALUES (37, 'count');
INSERT INTO "public"."parameters" ("id", "name") VALUES (41, 'effect_interval');
INSERT INTO "public"."parameters" ("id", "name") VALUES (42, 'effect_radius');
INSERT INTO "public"."parameters" ("id", "name") VALUES (44, 'fever_duration');
INSERT INTO "public"."parameters" ("id", "name") VALUES (45, 'heal_amount');
INSERT INTO "public"."parameters" ("id", "name") VALUES (46, 'heal_interval');
INSERT INTO "public"."parameters" ("id", "name") VALUES (49, 'mana_cost');
INSERT INTO "public"."parameters" ("id", "name") VALUES (51, 'max_mana');
INSERT INTO "public"."parameters" ("id", "name") VALUES (60, 'range');
INSERT INTO "public"."parameters" ("id", "name") VALUES (70, 'chain_lightning_cooldown');
INSERT INTO "public"."parameters" ("id", "name") VALUES (72, 'spawn_interval');
INSERT INTO "public"."parameters" ("id", "name") VALUES (73, 'sub_attack_interval');
INSERT INTO "public"."parameters" ("id", "name") VALUES (74, 'pull_mass_limit');
INSERT INTO "public"."parameters" ("id", "name") VALUES (75, 'beam_width');
INSERT INTO "public"."parameters" ("id", "name") VALUES (76, 'acceleration');
INSERT INTO "public"."parameters" ("id", "name") VALUES (78, 'trigger_delay');
INSERT INTO "public"."parameters" ("id", "name") VALUES (79, 'stun_duration');
INSERT INTO "public"."parameters" ("id", "name") VALUES (80, 'attack_offset');


--
-- Data for Name: prefab_elements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('aqua_archer', 'Water');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('bubble_generator', 'Water');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('bubble_spirit', 'Water');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('bubble_spirit', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('chain_lightning', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('chicken_commando', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('cloud_dragon', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('cloud_dragon', 'Water');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('cloud_dragon', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('crater', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('crater_ember', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('dimension_toad', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('dimension_toad', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('electric_explode', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('electric_field', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('electric_shot', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('electric_slime', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('electric_summon', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('electric_tower', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('evil_ent', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('evil_ent', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('fire_child_spirit', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('fire_drop', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('fire_explode', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('fire_field', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('fire_lord_spirit', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('fire_lord_spirit', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('fire_rune', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('fire_shot', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('fire_slime', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('fire_spirit', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('fire_spirit', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('fire_summon', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('fire_tadpole', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('giant_vine', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('ground_cannon', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('ground_tower', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('healing_totem', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('healing_totem', 'Water');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('leaf_explode', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('leaf_field', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('leaf_slime', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('leafair', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('life_tree', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('lightning_cloud', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('lightning_rune', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('lightning_tadpole', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('magma_explosion', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('magma_fist', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('magma_fist', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('magma_spirit', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('magma_spirit', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('mana_well', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('mana_well', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('meteor_drop', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('meteor_drop', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('meteor_shower', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('meteor_shower', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('mini_rock', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('nature_drop', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('nature_rune', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('overgrowth', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('pve_nature_slime_nest', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('pve_vine_colony', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('pve_vine_witch', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('pve_water_slime_nest', 'Water');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('rallying_totem', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('razor_gale', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('rock_drop', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('rock_explode', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('rock_golem', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('rock_mage', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('rock_remnant', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('rock_rolling', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('rock_rune', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('rock_slime', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('rock_summon', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('rock_turret', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('sand_storm', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('sand_storm', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('sea_serpent', 'Water');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('seed_nest', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('seed_spirit', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('shock_overload', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('storm_rider', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('storm_rider', 'Water');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('storm_stag', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('thunder_bird', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('thunder_spirit', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('thunder_spirit', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('tide_call', 'Water');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('tornado_strike', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('tornado_strike', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('towerback', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('tree_golem', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('vine', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('vine_colony', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('vine_spirit', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('vine_toss', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('water_explode', 'Water');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('water_explosion', 'Water');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('water_field', 'Water');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('water_rune', 'Water');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('water_shot', 'Water');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('water_slime', 'Water');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('wind_blade', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('wind_drop', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('wind_explode', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('wind_rune', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('wind_slime', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('wind_spirit', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('wind_summon', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('wind_totem', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('zap_mouse', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('wall_golem', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('shock_trap', 'Lightning');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('repair_totem', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('grass_generator', 'Nature');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('dragon_tower', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('dragon_flame', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('firework_tower', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('firework_shell', 'Fire');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('titan_remnant', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('titan_fist', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('tidal_warhead', 'Water');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('ground_tidal_warhead', 'Water');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('boulder_strike', 'Rock');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('boulder_strike', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('bomb_sprite', 'Wind');
INSERT INTO "public"."prefab_elements" ("prefab", "element") VALUES ('bomb_sprite_bomb', 'Wind');


--
-- Data for Name: pve_scenario_event_lines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."pve_scenario_event_lines" ("id", "event_row_id", "line_order", "line_text") VALUES (1, 111, 1, 'Stage 1-1');
INSERT INTO "public"."pve_scenario_event_lines" ("id", "event_row_id", "line_order", "line_text") VALUES (2, 111, 2, 'Destroy the enemy nest!');
INSERT INTO "public"."pve_scenario_event_lines" ("id", "event_row_id", "line_order", "line_text") VALUES (3, 112, 1, 'Burn it all down!');
INSERT INTO "public"."pve_scenario_event_lines" ("id", "event_row_id", "line_order", "line_text") VALUES (4, 121, 1, 'Stage 1-2');
INSERT INTO "public"."pve_scenario_event_lines" ("id", "event_row_id", "line_order", "line_text") VALUES (5, 121, 2, 'Destroy the enemy nest!');
INSERT INTO "public"."pve_scenario_event_lines" ("id", "event_row_id", "line_order", "line_text") VALUES (6, 122, 1, 'Burn it all down!');
INSERT INTO "public"."pve_scenario_event_lines" ("id", "event_row_id", "line_order", "line_text") VALUES (7, 131, 1, 'Stage 1-3');
INSERT INTO "public"."pve_scenario_event_lines" ("id", "event_row_id", "line_order", "line_text") VALUES (8, 131, 2, 'Destroy the vine colony!');
INSERT INTO "public"."pve_scenario_event_lines" ("id", "event_row_id", "line_order", "line_text") VALUES (9, 132, 1, 'Burn it all down!');
INSERT INTO "public"."pve_scenario_event_lines" ("id", "event_row_id", "line_order", "line_text") VALUES (10, 141, 1, 'Stage 1-4');
INSERT INTO "public"."pve_scenario_event_lines" ("id", "event_row_id", "line_order", "line_text") VALUES (11, 141, 2, 'Destroy the vine witch!');
INSERT INTO "public"."pve_scenario_event_lines" ("id", "event_row_id", "line_order", "line_text") VALUES (12, 142, 1, 'Burn it all down!');


--
-- Data for Name: pve_scenario_events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."pve_scenario_events" ("id", "event_id", "trigger_type", "trigger_value", "speaker_installer_id", "message_key", "sort_order", "scenario_id") VALUES (111, 'intro', 'FrameNumGte', 10, 'enemy_boss_1', 'pve_1_1_intro', 1, 1);
INSERT INTO "public"."pve_scenario_events" ("id", "event_id", "trigger_type", "trigger_value", "speaker_installer_id", "message_key", "sort_order", "scenario_id") VALUES (112, 'enemyLine', 'FrameNumGte', 20, 'enemy_boss_1', 'pve_1_1_enemy_line', 2, 1);
INSERT INTO "public"."pve_scenario_events" ("id", "event_id", "trigger_type", "trigger_value", "speaker_installer_id", "message_key", "sort_order", "scenario_id") VALUES (142, 'enemyLine', 'FrameNumGte', 20, 'pve_vine_witch', 'pve_1_4_enemy_line', 2, 4);
INSERT INTO "public"."pve_scenario_events" ("id", "event_id", "trigger_type", "trigger_value", "speaker_installer_id", "message_key", "sort_order", "scenario_id") VALUES (141, 'intro', 'FrameNumGte', 10, 'pve_vine_witch', 'pve_1_4_intro', 1, 4);
INSERT INTO "public"."pve_scenario_events" ("id", "event_id", "trigger_type", "trigger_value", "speaker_installer_id", "message_key", "sort_order", "scenario_id") VALUES (132, 'enemyLine', 'FrameNumGte', 20, 'pve_vine_colony', 'pve_1_3_enemy_line', 2, 3);
INSERT INTO "public"."pve_scenario_events" ("id", "event_id", "trigger_type", "trigger_value", "speaker_installer_id", "message_key", "sort_order", "scenario_id") VALUES (131, 'intro', 'FrameNumGte', 10, 'pve_vine_colony', 'pve_1_3_intro', 1, 3);
INSERT INTO "public"."pve_scenario_events" ("id", "event_id", "trigger_type", "trigger_value", "speaker_installer_id", "message_key", "sort_order", "scenario_id") VALUES (122, 'enemyLine', 'FrameNumGte', 20, 'water_nest', 'pve_1_2_enemy_line', 2, 2);
INSERT INTO "public"."pve_scenario_events" ("id", "event_id", "trigger_type", "trigger_value", "speaker_installer_id", "message_key", "sort_order", "scenario_id") VALUES (121, 'intro', 'FrameNumGte', 10, 'water_nest', 'pve_1_2_intro', 1, 2);


--
-- Data for Name: pve_scenario_installers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."pve_scenario_installers" ("id", "installer_id", "prefab_type", "master", "position_x", "position_y", "position_z", "sort_order", "scenario_id") VALUES (2, 'nature_nest', 'PveNatureSlimeNest', 'RightPlayer', 14, 0, 7, 1, 2);
INSERT INTO "public"."pve_scenario_installers" ("id", "installer_id", "prefab_type", "master", "position_x", "position_y", "position_z", "sort_order", "scenario_id") VALUES (5, 'pve_vine_witch', 'PveVineWitch', 'RightPlayer', 14, 0, 5, 1, 4);
INSERT INTO "public"."pve_scenario_installers" ("id", "installer_id", "prefab_type", "master", "position_x", "position_y", "position_z", "sort_order", "scenario_id") VALUES (3, 'water_nest', 'PveWaterSlimeNest', 'RightPlayer', 14, 0, 3, 2, 2);
INSERT INTO "public"."pve_scenario_installers" ("id", "installer_id", "prefab_type", "master", "position_x", "position_y", "position_z", "sort_order", "scenario_id") VALUES (1, 'enemy_boss_1', 'PveNatureSlimeNest', 'RightPlayer', 14, 0, 5, 1, 1);
INSERT INTO "public"."pve_scenario_installers" ("id", "installer_id", "prefab_type", "master", "position_x", "position_y", "position_z", "sort_order", "scenario_id") VALUES (4, 'pve_vine_colony', 'PveVineColony', 'RightPlayer', 14, 0, 5, 1, 3);


--
-- Data for Name: pve_scenario_objectives; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."pve_scenario_objectives" ("id", "installer_id", "sort_order", "scenario_id") VALUES (1, 'enemy_boss_1', 1, 1);
INSERT INTO "public"."pve_scenario_objectives" ("id", "installer_id", "sort_order", "scenario_id") VALUES (3, 'water_nest', 2, 2);
INSERT INTO "public"."pve_scenario_objectives" ("id", "installer_id", "sort_order", "scenario_id") VALUES (4, 'pve_vine_colony', 1, 3);
INSERT INTO "public"."pve_scenario_objectives" ("id", "installer_id", "sort_order", "scenario_id") VALUES (5, 'pve_vine_witch', 1, 4);
INSERT INTO "public"."pve_scenario_objectives" ("id", "installer_id", "sort_order", "scenario_id") VALUES (2, 'nature_nest', 1, 2);


--
-- Data for Name: quests; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."quests" ("id", "progress_checker", "require_value", "reward_giver", "access_type") VALUES (5, 'stage_clear_pc', 1, 'magic_rg', 'DEFAULT');
INSERT INTO "public"."quests" ("id", "progress_checker", "require_value", "reward_giver", "access_type") VALUES (6, 'stage_clear_pc', 1, 'magic_rg', 'DEFAULT');
INSERT INTO "public"."quests" ("id", "progress_checker", "require_value", "reward_giver", "access_type") VALUES (7, 'stage_clear_pc', 1, 'magic_rg', 'DEFAULT');
INSERT INTO "public"."quests" ("id", "progress_checker", "require_value", "reward_giver", "access_type") VALUES (8, 'stage_clear_pc', 1, 'magic_rg', 'DEFAULT');
INSERT INTO "public"."quests" ("id", "progress_checker", "require_value", "reward_giver", "access_type") VALUES (3, 'total_win_pc', 15, 'deco_rg', 'DEPRECATED');
INSERT INTO "public"."quests" ("id", "progress_checker", "require_value", "reward_giver", "access_type") VALUES (2, 'total_win_pc', 10, 'card_rg', 'DEPRECATED');
INSERT INTO "public"."quests" ("id", "progress_checker", "require_value", "reward_giver", "access_type") VALUES (1, 'total_win_pc', 5, 'card_rg', 'DEPRECATED');
INSERT INTO "public"."quests" ("id", "progress_checker", "require_value", "reward_giver", "access_type") VALUES (4, 'total_win_pc', 20, 'deco_rg', 'DEPRECATED');


--
-- Data for Name: reward_params; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."reward_params" ("id", "quest_id", "name", "value") VALUES (1, 1, 'card_id', 10);
INSERT INTO "public"."reward_params" ("id", "quest_id", "name", "value") VALUES (2, 2, 'card_id', 11);
INSERT INTO "public"."reward_params" ("id", "quest_id", "name", "value") VALUES (3, 3, 'decoration_id', 3);
INSERT INTO "public"."reward_params" ("id", "quest_id", "name", "value") VALUES (4, 4, 'decoration_id', 4);
INSERT INTO "public"."reward_params" ("id", "quest_id", "name", "value") VALUES (5, 5, 'magic_id', 48);
INSERT INTO "public"."reward_params" ("id", "quest_id", "name", "value") VALUES (6, 6, 'magic_id', 49);
INSERT INTO "public"."reward_params" ("id", "quest_id", "name", "value") VALUES (7, 7, 'magic_id', 50);
INSERT INTO "public"."reward_params" ("id", "quest_id", "name", "value") VALUES (8, 8, 'magic_id', 27);


--
-- Data for Name: scenarios; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."scenarios" ("id", "stage_id") VALUES (1, 1);
INSERT INTO "public"."scenarios" ("id", "stage_id") VALUES (2, 1);
INSERT INTO "public"."scenarios" ("id", "stage_id") VALUES (3, 1);
INSERT INTO "public"."scenarios" ("id", "stage_id") VALUES (4, 1);


--
-- Data for Name: stages; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."stages" ("id", "adventure_id") VALUES (1, 1);


--
-- Data for Name: tag_counter_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."tag_counter_rules" ("id", "attacker_tag_id", "target_tag_id", "weight") VALUES (2, 5, 6, 1.5);
INSERT INTO "public"."tag_counter_rules" ("id", "attacker_tag_id", "target_tag_id", "weight") VALUES (3, 13, 10, 1.5);
INSERT INTO "public"."tag_counter_rules" ("id", "attacker_tag_id", "target_tag_id", "weight") VALUES (4, 3, 11, 1.5);
INSERT INTO "public"."tag_counter_rules" ("id", "attacker_tag_id", "target_tag_id", "weight") VALUES (5, 13, 12, 1.5);
INSERT INTO "public"."tag_counter_rules" ("id", "attacker_tag_id", "target_tag_id", "weight") VALUES (1, 5, 2, 1);


--
-- Data for Name: tags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."tags" ("id", "name") VALUES (1, 'TYPE_Unit');
INSERT INTO "public"."tags" ("id", "name") VALUES (2, 'CAT_Small');
INSERT INTO "public"."tags" ("id", "name") VALUES (3, 'CAT_Ranged');
INSERT INTO "public"."tags" ("id", "name") VALUES (4, 'CAT_Flying');
INSERT INTO "public"."tags" ("id", "name") VALUES (5, 'CAT_AoE');
INSERT INTO "public"."tags" ("id", "name") VALUES (6, 'CAT_Building');
INSERT INTO "public"."tags" ("id", "name") VALUES (7, 'TYPE_Data');
INSERT INTO "public"."tags" ("id", "name") VALUES (8, 'TYPE_Card');
INSERT INTO "public"."tags" ("id", "name") VALUES (9, 'CAT_Medium');
INSERT INTO "public"."tags" ("id", "name") VALUES (10, 'CAT_Large');
INSERT INTO "public"."tags" ("id", "name") VALUES (11, 'CAT_Melee');
INSERT INTO "public"."tags" ("id", "name") VALUES (12, 'CAT_Tank');
INSERT INTO "public"."tags" ("id", "name") VALUES (13, 'CAT_CC');


--
-- Data for Name: user_magics; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (1, -51, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (2, -38, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (3, -33, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (4, -29, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (5, -53, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (6, -43, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (7, -45, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (8, -57, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (9, -34, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (10, -34, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (11, -30, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (12, -61, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (13, -37, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (14, -35, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (15, -26, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (16, -59, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (17, -25, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (18, -39, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (19, -40, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (20, -22, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (21, -24, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (22, -44, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (23, -60, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (24, -18, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (25, -23, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (26, -43, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (27, -26, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (28, -19, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (29, -59, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (30, -53, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (31, -36, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (32, -38, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (33, -52, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (34, -33, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (35, -61, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (36, -25, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (37, -58, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (38, -41, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (39, -31, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (40, -31, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (41, -49, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (42, -51, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (43, -25, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (44, -61, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (45, -19, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (46, -54, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (47, -28, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (48, -51, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (49, -59, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (50, -44, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (51, -41, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (52, -20, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (53, -43, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (54, -62, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (55, -24, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (56, -36, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (57, -35, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (58, -45, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (59, -44, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (60, -21, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (61, -37, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (62, -40, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (63, -53, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (64, -23, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (65, -46, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (66, -18, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (67, -35, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (68, -20, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (69, -19, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (70, -56, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (71, -18, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (72, -49, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (73, -30, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (74, -29, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (75, -51, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (76, -60, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (77, -48, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (78, -34, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (79, -59, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (80, -39, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (81, -29, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (82, -28, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (83, -21, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (84, -50, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (85, -34, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (86, -48, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (87, -41, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (88, -28, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (89, -29, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (90, -45, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (91, -41, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (92, -47, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (93, -21, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (94, -30, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (95, -28, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (96, -49, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (97, -32, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (98, -42, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (99, -32, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (100, -48, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (101, -37, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (102, -34, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (103, -55, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (104, -26, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (105, -35, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (106, -54, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (107, -22, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (108, -40, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (109, -23, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (110, -31, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (111, -47, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (112, -22, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (113, -39, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (114, -55, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (115, -58, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (116, -43, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (117, -20, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (118, -17, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (119, -24, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (120, -23, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (121, -46, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (122, -45, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (123, -18, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (124, -20, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (125, -30, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (126, -27, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (127, -24, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (128, -53, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (129, -56, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (130, -47, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (131, -48, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (132, -56, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (133, -43, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (134, -33, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (135, -33, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (136, -57, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (137, -50, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (138, -22, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (139, -62, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (140, -40, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (141, -46, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (142, -54, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (143, -21, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (144, -19, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (145, -54, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (146, -26, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (147, -54, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (148, -49, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (149, -47, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (150, -29, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (151, -25, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (152, -56, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (153, -53, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (154, -36, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (155, -24, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (156, -55, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (157, -32, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (158, -20, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (159, -57, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (160, -57, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (161, -52, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (162, -42, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (163, -56, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (164, -39, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (165, -50, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (166, -31, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (167, -46, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (168, -58, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (169, -37, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (170, -33, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (171, -59, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (172, -27, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (173, -40, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (174, -36, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (175, -58, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (176, -50, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (177, -42, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (178, -35, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (179, -61, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (180, -36, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (181, -52, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (182, -45, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (183, -42, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (184, -62, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (185, -52, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (186, -30, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (187, -17, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (188, -21, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (189, -31, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (190, -60, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (191, -38, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (192, -52, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (193, -25, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (194, -60, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (195, -55, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (196, -42, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (197, -38, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (198, -38, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (199, -22, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (200, -44, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (201, -44, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (202, -60, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (203, -47, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (204, -48, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (205, -62, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (206, -18, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (207, -46, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (208, -50, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (209, -41, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (210, -27, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (211, -28, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (212, -26, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (213, -17, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (214, -62, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (215, -55, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (216, -32, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (217, -27, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (218, -17, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (219, -39, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (220, -17, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (221, -19, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (222, -61, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (223, -51, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (224, -49, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (225, -32, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (226, -57, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (227, -27, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (228, -37, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (229, -58, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (230, -23, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (231, -19, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (232, -19, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (233, -19, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (234, -19, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (235, -19, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (236, -24, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (237, -24, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (238, -24, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (239, -24, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (240, -24, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (241, -29, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (242, -29, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (243, -29, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (244, -29, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (245, -29, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (246, -34, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (247, -34, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (248, -34, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (249, -34, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (250, -34, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (251, -39, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (252, -39, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (253, -39, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (254, -39, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (255, -39, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (256, -44, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (257, -44, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (258, -44, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (259, -44, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (260, -44, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (261, -49, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (262, -49, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (263, -49, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (264, -49, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (265, -49, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (266, -54, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (267, -54, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (268, -54, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (269, -54, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (270, -54, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (271, -59, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (272, -59, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (273, -59, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (274, -59, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (275, -59, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (276, -17, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (277, -17, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (278, -17, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (279, -17, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (280, -17, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (281, -18, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (282, -18, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (283, -18, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (284, -18, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (285, -18, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (286, -20, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (287, -20, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (288, -20, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (289, -20, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (290, -20, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (291, -21, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (292, -21, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (293, -21, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (294, -21, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (295, -21, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (296, -22, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (297, -22, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (298, -22, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (299, -22, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (300, -22, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (301, -23, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (302, -23, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (303, -23, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (304, -23, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (305, -23, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (306, -25, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (307, -25, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (308, -25, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (309, -25, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (310, -25, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (311, -26, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (312, -26, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (313, -26, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (314, -26, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (315, -26, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (316, -27, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (317, -27, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (318, -27, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (319, -27, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (320, -27, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (321, -28, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (322, -28, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (323, -28, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (324, -28, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (325, -28, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (326, -30, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (327, -30, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (328, -30, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (329, -30, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (330, -30, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (331, -31, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (332, -31, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (333, -31, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (334, -31, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (335, -31, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (336, -32, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (337, -32, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (338, -32, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (339, -32, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (340, -32, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (341, -33, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (342, -33, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (343, -33, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (344, -33, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (345, -33, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (346, -35, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (347, -35, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (348, -35, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (349, -35, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (350, -35, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (351, -36, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (352, -36, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (353, -36, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (354, -36, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (355, -36, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (356, -37, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (357, -37, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (358, -37, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (359, -37, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (360, -37, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (361, -38, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (362, -38, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (363, -38, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (364, -38, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (365, -38, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (366, -40, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (367, -40, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (368, -40, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (369, -40, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (370, -40, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (371, -41, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (372, -41, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (373, -41, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (374, -41, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (375, -41, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (376, -42, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (377, -42, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (378, -42, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (379, -42, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (380, -42, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (381, -43, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (382, -43, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (383, -43, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (384, -43, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (385, -43, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (386, -45, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (387, -45, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (388, -45, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (389, -45, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (390, -45, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (391, -46, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (392, -46, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (393, -46, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (394, -46, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (395, -46, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (396, -47, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (397, -47, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (398, -47, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (399, -47, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (400, -47, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (401, -48, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (402, -48, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (403, -48, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (404, -48, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (405, -48, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (406, -50, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (407, -50, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (408, -50, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (409, -50, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (410, -50, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (411, -51, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (412, -51, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (413, -51, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (414, -51, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (415, -51, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (416, -52, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (417, -52, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (418, -52, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (419, -52, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (420, -52, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (421, -53, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (422, -53, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (423, -53, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (424, -53, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (425, -53, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (426, -55, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (427, -55, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (428, -55, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (429, -55, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (430, -55, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (431, -56, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (432, -56, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (433, -56, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (434, -56, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (435, -56, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (436, -57, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (437, -57, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (438, -57, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (439, -57, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (440, -57, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (441, -58, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (442, -58, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (443, -58, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (444, -58, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (445, -58, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (446, -60, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (447, -60, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (448, -60, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (449, -60, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (450, -60, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (451, -61, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (452, -61, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (453, -61, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (454, -61, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (455, -61, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (456, -62, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (457, -62, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (458, -62, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (459, -62, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (460, -62, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (461, -1, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (462, -1, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (463, -1, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (464, -1, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (465, -1, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (466, -1, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (467, -1, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (468, -1, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (469, -1, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (470, -1, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (471, -6, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (472, -6, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (473, -6, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (474, -6, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (475, -6, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (476, -6, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (477, -6, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (478, -6, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (479, -6, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (480, -6, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (481, -7, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (482, -7, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (483, -7, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (484, -7, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (485, -7, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (486, -7, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (487, -7, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (488, -7, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (489, -7, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (490, -7, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (491, -8, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (492, -8, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (493, -8, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (494, -8, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (495, -8, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (496, -8, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (497, -8, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (498, -8, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (499, -8, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (500, -8, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (501, -9, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (502, -9, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (503, -9, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (504, -9, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (505, -9, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (506, -9, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (507, -9, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (508, -9, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (509, -9, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (510, -9, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (511, -10, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (512, -10, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (513, -10, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (514, -10, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (515, -10, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (516, -10, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (517, -10, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (518, -10, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (519, -10, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (520, -10, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (521, -11, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (522, -11, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (523, -11, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (524, -11, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (525, -11, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (526, -11, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (527, -11, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (528, -11, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (529, -11, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (530, -11, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (531, -12, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (532, -12, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (533, -12, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (534, -12, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (535, -12, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (536, -12, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (537, -12, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (538, -12, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (539, -12, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (540, -12, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (541, -13, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (542, -13, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (543, -13, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (544, -13, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (545, -13, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (546, -13, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (547, -13, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (548, -13, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (549, -13, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (550, -13, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (551, -14, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (552, -14, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (553, -14, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (554, -14, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (555, -14, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (556, -14, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (557, -14, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (558, -14, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (559, -14, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (560, -14, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (561, -15, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (562, -15, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (563, -15, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (564, -15, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (565, -15, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (566, -15, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (567, -15, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (568, -15, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (569, -15, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (570, -15, 84, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (571, -16, 35, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (572, -16, 24, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (573, -16, 55, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (574, -16, 54, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (575, -16, 19, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (576, -16, 83, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (577, -16, 80, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (578, -16, 81, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (579, -16, 82, 3);
INSERT INTO "public"."user_magics" ("id", "user_id", "magic_id", "count") VALUES (580, -16, 84, 3);


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-17, 1, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-18, 2, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-19, 3, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-20, 4, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-21, 5, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-22, 6, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-23, 7, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-24, 8, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-25, 9, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-26, 10, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-27, 11, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-28, 12, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-29, 13, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-30, 14, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-31, 15, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-32, 16, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-33, 17, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-34, 18, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-35, 19, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-36, 20, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-37, 21, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-38, 22, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-39, 23, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-40, 24, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-41, 25, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-42, 26, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-43, 27, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-44, 28, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-49, 33, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-54, 38, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-59, 43, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-1, 47, 1000, '2026-09-16 10:11:17.919237', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-45, 29, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-46, 30, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-47, 31, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-48, 32, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-50, 34, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-51, 35, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-52, 36, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-53, 37, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-55, 39, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-56, 40, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-57, 41, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-58, 42, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-60, 44, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-61, 45, 1000, '2026-09-16 10:06:02.663011', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-62, 46, 600, '2026-09-16 10:06:03.099362', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-6, 49, 1000, '2026-09-16 10:11:17.919237', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-7, 50, 1000, '2026-09-16 10:11:17.919237', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-8, 51, 1000, '2026-09-16 10:11:17.919237', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-9, 52, 1000, '2026-09-16 10:11:17.919237', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-10, 53, 1000, '2026-09-16 10:11:17.919237', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-11, 54, 1000, '2026-09-16 10:11:17.919237', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-12, 55, 1000, '2026-09-16 10:11:17.919237', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-13, 56, 1000, '2026-09-16 10:11:17.919237', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-14, 57, 1000, '2026-09-16 10:11:17.919237', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-15, 58, 1000, '2026-09-16 10:11:17.919237', 'Online', 0, 1);
INSERT INTO "public"."users" ("id", "selected_deck_id", "mmr", "created_at", "status", "total_wins", "novice_progress") VALUES (-16, 59, 1000, '2026-09-16 10:11:17.919237', 'Online', 0, 1);


--
-- Name: adventures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."adventures_id_seq"', 1, true);


--
-- Name: bot_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."bot_user_id_seq"', -62, true);


--
-- Name: deck_cards_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."deck_cards_id_seq"', 539, true);


--
-- Name: decks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."decks_id_seq"', 59, true);


--
-- Name: decorations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."decorations_id_seq"', 4, true);


--
-- Name: deploy_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."deploy_status_id_seq"', 1, false);


--
-- Name: game_object_tags_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."game_object_tags_id_seq"', 477, true);


--
-- Name: game_objects_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."game_objects_id_seq"', 237, true);


--
-- Name: magic_parameters_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."magic_parameters_id_seq"', 11, true);


--
-- Name: magics_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."magics_id_seq"', 84, true);


--
-- Name: parameter_values_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."parameter_values_id_seq"', 1257, true);


--
-- Name: parameters_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."parameters_id_seq"', 80, true);


--
-- Name: pve_scenario_event_lines_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."pve_scenario_event_lines_id_seq"', 12, true);


--
-- Name: pve_scenario_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."pve_scenario_events_id_seq"', 142, true);


--
-- Name: pve_scenario_installers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."pve_scenario_installers_id_seq"', 5, true);


--
-- Name: pve_scenario_objectives_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."pve_scenario_objectives_id_seq"', 5, true);


--
-- Name: quests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."quests_id_seq"', 8, true);


--
-- Name: reward_params_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."reward_params_id_seq"', 8, true);


--
-- Name: scenarios_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."scenarios_id_seq"', 4, true);


--
-- Name: servers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."servers_id_seq"', 1, false);


--
-- Name: stages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."stages_id_seq"', 1, true);


--
-- Name: statistic_game_decks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."statistic_game_decks_id_seq"', 1, false);


--
-- Name: statistic_game_magics_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."statistic_game_magics_id_seq"', 1, false);


--
-- Name: statistic_game_sessions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."statistic_game_sessions_id_seq"', 1, false);


--
-- Name: statistic_games_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."statistic_games_id_seq"', 1, false);


--
-- Name: statistic_update_time_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."statistic_update_time_id_seq"', 1, false);


--
-- Name: tag_counter_rules_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."tag_counter_rules_id_seq"', 5, true);


--
-- Name: tags_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."tags_id_seq"', 13, true);


--
-- Name: user_adventures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."user_adventures_id_seq"', 1, false);


--
-- Name: user_decorations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."user_decorations_id_seq"', 1, false);


--
-- Name: user_magics_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."user_magics_id_seq"', 580, true);


--
-- Name: user_quests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."user_quests_id_seq"', 1, false);


--
-- Name: user_scenarios_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."user_scenarios_id_seq"', 1, false);


--
-- Name: user_stages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."user_stages_id_seq"', 1, false);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."users_id_seq"', 1, false);


--
-- Name: adventures adventures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."adventures"
    ADD CONSTRAINT "adventures_pkey" PRIMARY KEY ("id");


--
-- Name: bot_personas bot_personas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bot_personas"
    ADD CONSTRAINT "bot_personas_pkey" PRIMARY KEY ("user_id");


--
-- Name: deck_cards deck_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."deck_cards"
    ADD CONSTRAINT "deck_cards_pkey" PRIMARY KEY ("id");


--
-- Name: decks decks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."decks"
    ADD CONSTRAINT "decks_pkey" PRIMARY KEY ("id");


--
-- Name: decorations decorations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."decorations"
    ADD CONSTRAINT "decorations_pkey" PRIMARY KEY ("id");


--
-- Name: deploy_status deploy_status_deploy_type_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."deploy_status"
    ADD CONSTRAINT "deploy_status_deploy_type_key" UNIQUE ("deploy_type");


--
-- Name: deploy_status deploy_status_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."deploy_status"
    ADD CONSTRAINT "deploy_status_pkey" PRIMARY KEY ("id");


--
-- Name: game_object_tags game_object_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."game_object_tags"
    ADD CONSTRAINT "game_object_tags_pkey" PRIMARY KEY ("id");


--
-- Name: game_objects game_objects_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."game_objects"
    ADD CONSTRAINT "game_objects_name_key" UNIQUE ("name");


--
-- Name: game_objects game_objects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."game_objects"
    ADD CONSTRAINT "game_objects_pkey" PRIMARY KEY ("id");


--
-- Name: magic_game_object_aliases magic_game_object_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."magic_game_object_aliases"
    ADD CONSTRAINT "magic_game_object_aliases_pkey" PRIMARY KEY ("magic_name");


--
-- Name: magic_parameters magic_parameters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."magic_parameters"
    ADD CONSTRAINT "magic_parameters_pkey" PRIMARY KEY ("id");


--
-- Name: magic_tags magic_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."magic_tags"
    ADD CONSTRAINT "magic_tags_pkey" PRIMARY KEY ("magic_id", "tag_id");


--
-- Name: magics magics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."magics"
    ADD CONSTRAINT "magics_pkey" PRIMARY KEY ("id");


--
-- Name: parameter_values parameter_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."parameter_values"
    ADD CONSTRAINT "parameter_values_pkey" PRIMARY KEY ("id");


--
-- Name: parameters parameters_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."parameters"
    ADD CONSTRAINT "parameters_name_key" UNIQUE ("name");


--
-- Name: parameters parameters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."parameters"
    ADD CONSTRAINT "parameters_pkey" PRIMARY KEY ("id");


--
-- Name: prefab_elements pk_prefab_elements; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."prefab_elements"
    ADD CONSTRAINT "pk_prefab_elements" PRIMARY KEY ("prefab", "element");


--
-- Name: pve_scenario_event_lines pve_scenario_event_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."pve_scenario_event_lines"
    ADD CONSTRAINT "pve_scenario_event_lines_pkey" PRIMARY KEY ("id");


--
-- Name: pve_scenario_events pve_scenario_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."pve_scenario_events"
    ADD CONSTRAINT "pve_scenario_events_pkey" PRIMARY KEY ("id");


--
-- Name: pve_scenario_installers pve_scenario_installers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."pve_scenario_installers"
    ADD CONSTRAINT "pve_scenario_installers_pkey" PRIMARY KEY ("id");


--
-- Name: pve_scenario_objectives pve_scenario_objectives_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."pve_scenario_objectives"
    ADD CONSTRAINT "pve_scenario_objectives_pkey" PRIMARY KEY ("id");


--
-- Name: quests quests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."quests"
    ADD CONSTRAINT "quests_pkey" PRIMARY KEY ("id");


--
-- Name: reward_params reward_params_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."reward_params"
    ADD CONSTRAINT "reward_params_pkey" PRIMARY KEY ("id");


--
-- Name: scenarios scenarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."scenarios"
    ADD CONSTRAINT "scenarios_pkey" PRIMARY KEY ("id");


--
-- Name: servers servers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."servers"
    ADD CONSTRAINT "servers_pkey" PRIMARY KEY ("id");


--
-- Name: stages stages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stages"
    ADD CONSTRAINT "stages_pkey" PRIMARY KEY ("id");


--
-- Name: statistic_game_decks statistic_game_decks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."statistic_game_decks"
    ADD CONSTRAINT "statistic_game_decks_pkey" PRIMARY KEY ("id");


--
-- Name: statistic_game_magics statistic_game_magics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."statistic_game_magics"
    ADD CONSTRAINT "statistic_game_magics_pkey" PRIMARY KEY ("id");


--
-- Name: statistic_game_sessions statistic_game_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."statistic_game_sessions"
    ADD CONSTRAINT "statistic_game_sessions_pkey" PRIMARY KEY ("id");


--
-- Name: statistic_games statistic_games_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."statistic_games"
    ADD CONSTRAINT "statistic_games_pkey" PRIMARY KEY ("id");


--
-- Name: statistic_update_time statistic_update_time_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."statistic_update_time"
    ADD CONSTRAINT "statistic_update_time_pkey" PRIMARY KEY ("id");


--
-- Name: tag_counter_rules tag_counter_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."tag_counter_rules"
    ADD CONSTRAINT "tag_counter_rules_pkey" PRIMARY KEY ("id");


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."tags"
    ADD CONSTRAINT "tags_pkey" PRIMARY KEY ("id");


--
-- Name: deck_cards uq_deck_cards_magic_id_deck_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."deck_cards"
    ADD CONSTRAINT "uq_deck_cards_magic_id_deck_id" UNIQUE ("magic_id", "deck_id");


--
-- Name: game_object_tags uq_game_object_id_tag_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."game_object_tags"
    ADD CONSTRAINT "uq_game_object_id_tag_id" UNIQUE ("game_object_id", "tag_id");


--
-- Name: magic_parameters uq_magic_parameter; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."magic_parameters"
    ADD CONSTRAINT "uq_magic_parameter" UNIQUE ("magic_id", "parameter_id");


--
-- Name: magics uq_magics_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."magics"
    ADD CONSTRAINT "uq_magics_name" UNIQUE ("name");


--
-- Name: parameter_values uq_parameter_game_object; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."parameter_values"
    ADD CONSTRAINT "uq_parameter_game_object" UNIQUE ("parameter_id", "game_object_id");


--
-- Name: pve_scenario_event_lines uq_pve_scenario_event_line_row_order; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."pve_scenario_event_lines"
    ADD CONSTRAINT "uq_pve_scenario_event_line_row_order" UNIQUE ("event_row_id", "line_order");


--
-- Name: reward_params uq_reward_params_quest_id_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."reward_params"
    ADD CONSTRAINT "uq_reward_params_quest_id_name" UNIQUE ("quest_id", "name");


--
-- Name: tag_counter_rules uq_tag_counter_rules_pair; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."tag_counter_rules"
    ADD CONSTRAINT "uq_tag_counter_rules_pair" UNIQUE ("attacker_tag_id", "target_tag_id");


--
-- Name: tags uq_tags_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."tags"
    ADD CONSTRAINT "uq_tags_name" UNIQUE ("name");


--
-- Name: user_scenarios uq_user_adventures_user_id_scenario_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_scenarios"
    ADD CONSTRAINT "uq_user_adventures_user_id_scenario_id" UNIQUE ("user_id", "scenario_id");


--
-- Name: user_magics uq_user_magics_user_id_magic_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_magics"
    ADD CONSTRAINT "uq_user_magics_user_id_magic_id" UNIQUE ("user_id", "magic_id");


--
-- Name: user_decorations user_decorations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_decorations"
    ADD CONSTRAINT "user_decorations_pkey" PRIMARY KEY ("id");


--
-- Name: user_magics user_magics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_magics"
    ADD CONSTRAINT "user_magics_pkey" PRIMARY KEY ("id");


--
-- Name: user_quests user_quests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_quests"
    ADD CONSTRAINT "user_quests_pkey" PRIMARY KEY ("id");


--
-- Name: user_scenarios user_scenarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_scenarios"
    ADD CONSTRAINT "user_scenarios_pkey" PRIMARY KEY ("id");


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");


--
-- Name: idx_bot_personas_enabled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_bot_personas_enabled" ON "public"."bot_personas" USING "btree" ("enabled", "user_id");


--
-- Name: idx_bot_personas_hospitality; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_bot_personas_hospitality" ON "public"."bot_personas" USING "btree" ("hospitality", "enabled") WHERE "hospitality";


--
-- Name: idx_magic_parameters_magic; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_magic_parameters_magic" ON "public"."magic_parameters" USING "btree" ("magic_id");


--
-- Name: idx_magic_tags_magic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_magic_tags_magic_id" ON "public"."magic_tags" USING "btree" ("magic_id");


--
-- Name: idx_magics_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_magics_updated_at" ON "public"."magics" USING "btree" ("updated_at");


--
-- Name: idx_parameter_values_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_parameter_values_updated_at" ON "public"."parameter_values" USING "btree" ("updated_at");


--
-- Name: idx_servers_type_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_servers_type_state" ON "public"."servers" USING "btree" ("type", "state");


--
-- Name: idx_statistic_game_deck_user_id_statistic_game_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_statistic_game_deck_user_id_statistic_game_id" ON "public"."statistic_game_decks" USING "btree" ("user_id", "statistic_game_id");


--
-- Name: idx_statistic_game_magic_user_id_statistic_game_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_statistic_game_magic_user_id_statistic_game_id" ON "public"."statistic_game_magics" USING "btree" ("user_id", "statistic_game_id");


--
-- Name: idx_statistic_game_sessions_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_statistic_game_sessions_started_at" ON "public"."statistic_game_sessions" USING "btree" ("started_at" DESC);


--
-- Name: idx_statistic_game_sessions_status_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_statistic_game_sessions_status_started_at" ON "public"."statistic_game_sessions" USING "btree" ("status", "started_at" DESC);


--
-- Name: idx_statistic_games_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_statistic_games_created_at" ON "public"."statistic_games" USING "btree" ("created_at");


--
-- Name: idx_users_novice_progress; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_users_novice_progress" ON "public"."users" USING "btree" ("novice_progress") WHERE ("novice_progress" < (1.0)::double precision);


--
-- Name: parameter_values update_parameter_values_modtime; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "update_parameter_values_modtime" BEFORE UPDATE ON "public"."parameter_values" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();


--
-- Name: bot_personas bot_personas_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bot_personas"
    ADD CONSTRAINT "bot_personas_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;


--
-- Name: deck_cards deck_cards_deck_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."deck_cards"
    ADD CONSTRAINT "deck_cards_deck_id_fkey" FOREIGN KEY ("deck_id") REFERENCES "public"."decks"("id") ON DELETE CASCADE;


--
-- Name: deck_cards fk_deck_cards_magic_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."deck_cards"
    ADD CONSTRAINT "fk_deck_cards_magic_id" FOREIGN KEY ("magic_id") REFERENCES "public"."magics"("id");


--
-- Name: parameter_values fk_game_object; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."parameter_values"
    ADD CONSTRAINT "fk_game_object" FOREIGN KEY ("game_object_id") REFERENCES "public"."game_objects"("id");


--
-- Name: parameter_values fk_parameter; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."parameter_values"
    ADD CONSTRAINT "fk_parameter" FOREIGN KEY ("parameter_id") REFERENCES "public"."parameters"("id");


--
-- Name: game_object_tags game_object_tags_game_object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."game_object_tags"
    ADD CONSTRAINT "game_object_tags_game_object_id_fkey" FOREIGN KEY ("game_object_id") REFERENCES "public"."game_objects"("id");


--
-- Name: game_object_tags game_object_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."game_object_tags"
    ADD CONSTRAINT "game_object_tags_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "public"."tags"("id");


--
-- Name: magic_parameters magic_parameters_magic_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."magic_parameters"
    ADD CONSTRAINT "magic_parameters_magic_id_fkey" FOREIGN KEY ("magic_id") REFERENCES "public"."magics"("id") ON DELETE CASCADE;


--
-- Name: magic_parameters magic_parameters_parameter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."magic_parameters"
    ADD CONSTRAINT "magic_parameters_parameter_id_fkey" FOREIGN KEY ("parameter_id") REFERENCES "public"."parameters"("id") ON DELETE RESTRICT;


--
-- Name: magic_tags magic_tags_magic_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."magic_tags"
    ADD CONSTRAINT "magic_tags_magic_id_fkey" FOREIGN KEY ("magic_id") REFERENCES "public"."magics"("id") ON DELETE CASCADE;


--
-- Name: magic_tags magic_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."magic_tags"
    ADD CONSTRAINT "magic_tags_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "public"."tags"("id") ON DELETE CASCADE;


--
-- Name: pve_scenario_event_lines pve_scenario_event_lines_event_row_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."pve_scenario_event_lines"
    ADD CONSTRAINT "pve_scenario_event_lines_event_row_id_fkey" FOREIGN KEY ("event_row_id") REFERENCES "public"."pve_scenario_events"("id") ON DELETE CASCADE;


--
-- Name: pve_scenario_events pve_scenario_events_scenario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."pve_scenario_events"
    ADD CONSTRAINT "pve_scenario_events_scenario_id_fkey" FOREIGN KEY ("scenario_id") REFERENCES "public"."scenarios"("id") ON DELETE CASCADE;


--
-- Name: pve_scenario_installers pve_scenario_installers_scenario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."pve_scenario_installers"
    ADD CONSTRAINT "pve_scenario_installers_scenario_id_fkey" FOREIGN KEY ("scenario_id") REFERENCES "public"."scenarios"("id") ON DELETE CASCADE;


--
-- Name: pve_scenario_objectives pve_scenario_objectives_scenario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."pve_scenario_objectives"
    ADD CONSTRAINT "pve_scenario_objectives_scenario_id_fkey" FOREIGN KEY ("scenario_id") REFERENCES "public"."scenarios"("id") ON DELETE CASCADE;


--
-- Name: reward_params reward_params_quest_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."reward_params"
    ADD CONSTRAINT "reward_params_quest_id_fkey" FOREIGN KEY ("quest_id") REFERENCES "public"."quests"("id") ON DELETE CASCADE;


--
-- Name: scenarios scenarios_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."scenarios"
    ADD CONSTRAINT "scenarios_stage_id_fkey" FOREIGN KEY ("stage_id") REFERENCES "public"."stages"("id") ON DELETE CASCADE;


--
-- Name: stages stages_adventure_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stages"
    ADD CONSTRAINT "stages_adventure_id_fkey" FOREIGN KEY ("adventure_id") REFERENCES "public"."adventures"("id") ON DELETE CASCADE;


--
-- Name: statistic_game_decks statistic_game_decks_magic_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."statistic_game_decks"
    ADD CONSTRAINT "statistic_game_decks_magic_id_fkey" FOREIGN KEY ("magic_id") REFERENCES "public"."magics"("id");


--
-- Name: statistic_game_decks statistic_game_decks_statistic_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."statistic_game_decks"
    ADD CONSTRAINT "statistic_game_decks_statistic_game_id_fkey" FOREIGN KEY ("statistic_game_id") REFERENCES "public"."statistic_games"("id") ON DELETE CASCADE;


--
-- Name: statistic_game_magics statistic_game_magics_magic_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."statistic_game_magics"
    ADD CONSTRAINT "statistic_game_magics_magic_id_fkey" FOREIGN KEY ("magic_id") REFERENCES "public"."magics"("id");


--
-- Name: statistic_game_magics statistic_game_magics_statistic_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."statistic_game_magics"
    ADD CONSTRAINT "statistic_game_magics_statistic_game_id_fkey" FOREIGN KEY ("statistic_game_id") REFERENCES "public"."statistic_games"("id") ON DELETE CASCADE;


--
-- Name: statistic_game_sessions statistic_game_sessions_statistic_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."statistic_game_sessions"
    ADD CONSTRAINT "statistic_game_sessions_statistic_game_id_fkey" FOREIGN KEY ("statistic_game_id") REFERENCES "public"."statistic_games"("id") ON DELETE SET NULL;


--
-- Name: statistic_update_time statistic_update_time_statistic_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."statistic_update_time"
    ADD CONSTRAINT "statistic_update_time_statistic_game_id_fkey" FOREIGN KEY ("statistic_game_id") REFERENCES "public"."statistic_games"("id") ON DELETE CASCADE;


--
-- Name: tag_counter_rules tag_counter_rules_attacker_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."tag_counter_rules"
    ADD CONSTRAINT "tag_counter_rules_attacker_tag_id_fkey" FOREIGN KEY ("attacker_tag_id") REFERENCES "public"."tags"("id");


--
-- Name: tag_counter_rules tag_counter_rules_target_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."tag_counter_rules"
    ADD CONSTRAINT "tag_counter_rules_target_tag_id_fkey" FOREIGN KEY ("target_tag_id") REFERENCES "public"."tags"("id");


--
-- Name: user_decorations user_decorations_decoration_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_decorations"
    ADD CONSTRAINT "user_decorations_decoration_id_fkey" FOREIGN KEY ("decoration_id") REFERENCES "public"."decorations"("id");


--
-- Name: user_magics user_magics_magic_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_magics"
    ADD CONSTRAINT "user_magics_magic_id_fkey" FOREIGN KEY ("magic_id") REFERENCES "public"."magics"("id") ON DELETE CASCADE;


--
-- Name: user_magics user_magics_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_magics"
    ADD CONSTRAINT "user_magics_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;


--
-- Name: user_quests user_quests_quest_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_quests"
    ADD CONSTRAINT "user_quests_quest_id_fkey" FOREIGN KEY ("quest_id") REFERENCES "public"."quests"("id") ON DELETE CASCADE;


--
-- Name: user_quests user_quests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_quests"
    ADD CONSTRAINT "user_quests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;


--
-- Name: user_scenarios user_scenarios_scenario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_scenarios"
    ADD CONSTRAINT "user_scenarios_scenario_id_fkey" FOREIGN KEY ("scenario_id") REFERENCES "public"."scenarios"("id") ON DELETE CASCADE;


--
-- Name: user_scenarios user_scenarios_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_scenarios"
    ADD CONSTRAINT "user_scenarios_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;


--
-- Name: users users_selected_deck_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_selected_deck_id_fkey" FOREIGN KEY ("selected_deck_id") REFERENCES "public"."decks"("id");


--
-- PostgreSQL database dump complete
--



-- Leave the session search_path where Flyway expects it.
SELECT pg_catalog.set_config('search_path', 'public', false);

-- V036: adds statistic_games.hosted_locally and the local_session_rejections table.
-- hosted_locally marks a game that ran on a game server the player started on their own machine.
-- local_session_rejections records each local game session the lobby refused to accept, with the
-- reason and the payload that was rejected.
-- Idempotent: ADD COLUMN IF NOT EXISTS, CREATE TABLE IF NOT EXISTS, CREATE INDEX IF NOT EXISTS.
-- Existing statistic_games rows get hosted_locally false.
-- no-tags: no game_objects or magics row is registered here.

ALTER TABLE "public"."statistic_games"
    ADD COLUMN IF NOT EXISTS "hosted_locally" boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS "public"."local_session_rejections" (
    "id" bigserial PRIMARY KEY,
    "user_id" bigint NOT NULL,
    "session_id" character varying(64) NOT NULL,
    "reason" character varying(64) NOT NULL,
    "payload" jsonb,
    "created_at" timestamp NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS "idx_local_session_rejections_user_id_created_at"
    ON "public"."local_session_rejections" ("user_id", "created_at");

COMMENT ON COLUMN statistic_games.hosted_locally IS
    'True when the game ran on a game server the player started locally. False for every game on a shared game server.';

COMMENT ON TABLE local_session_rejections IS
    'One row per local game session the lobby refused to accept. reason names the check that failed; payload holds the rejected submission.';

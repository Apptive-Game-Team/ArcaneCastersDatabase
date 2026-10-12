-- V034: adds stages.map_type, the visual map a PVE match of that stage uses.
-- The game server reads it and tells the client which map to load. It sits on the stage and
-- not on the adventure because the stages of one adventure can use different maps.
-- Allowed values: GRASSLAND (default), RIVER, FORTRESS, GATE, FOREST.
-- Backfill matches through stages.adventure_id to adventures.name, not by id: stages of
-- forest -> FOREST, fortress -> FORTRESS, gate -> GATE. A stage without an adventure, or of
-- any other adventure, keeps the default.
-- Idempotent: ADD COLUMN IF NOT EXISTS, the constraint is dropped before it is added, and
-- the backfill sets a fixed value per adventure name.
-- adventures is not changed.
-- no-tags: no game_objects or magics row is registered here.

ALTER TABLE "public"."stages"
    ADD COLUMN IF NOT EXISTS "map_type" text NOT NULL DEFAULT 'GRASSLAND';

ALTER TABLE "public"."stages"
    DROP CONSTRAINT IF EXISTS "chk_stages_map_type";

ALTER TABLE "public"."stages"
    ADD CONSTRAINT "chk_stages_map_type"
    CHECK ("map_type" IN ('GRASSLAND', 'RIVER', 'FORTRESS', 'GATE', 'FOREST'));

UPDATE "public"."stages" AS s SET "map_type" = 'FOREST'
FROM "public"."adventures" AS a
WHERE a."id" = s."adventure_id" AND a."name" = 'forest';

UPDATE "public"."stages" AS s SET "map_type" = 'FORTRESS'
FROM "public"."adventures" AS a
WHERE a."id" = s."adventure_id" AND a."name" = 'fortress';

UPDATE "public"."stages" AS s SET "map_type" = 'GATE'
FROM "public"."adventures" AS a
WHERE a."id" = s."adventure_id" AND a."name" = 'gate';

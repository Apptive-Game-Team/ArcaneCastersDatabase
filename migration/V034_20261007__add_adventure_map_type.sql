-- V034: adds adventures.map_type, the visual map a PVE match of that adventure uses.
-- The game server reads it and tells the client which map to load.
-- Allowed values: GRASSLAND (default), RIVER, FORTRESS, GATE, FOREST.
-- Backfill matches by adventure name, not id: forest -> FOREST, fortress -> FORTRESS,
-- gate -> GATE. Any other adventure keeps the default.
-- Idempotent: ADD COLUMN IF NOT EXISTS, the constraint is dropped before it is added, and
-- the backfill sets a fixed value per name.
-- no-tags: no game_objects or magics row is registered here.

ALTER TABLE "public"."adventures"
    ADD COLUMN IF NOT EXISTS "map_type" text NOT NULL DEFAULT 'GRASSLAND';

ALTER TABLE "public"."adventures"
    DROP CONSTRAINT IF EXISTS "chk_adventures_map_type";

ALTER TABLE "public"."adventures"
    ADD CONSTRAINT "chk_adventures_map_type"
    CHECK ("map_type" IN ('GRASSLAND', 'RIVER', 'FORTRESS', 'GATE', 'FOREST'));

UPDATE "public"."adventures" SET "map_type" = 'FOREST' WHERE "name" = 'forest';
UPDATE "public"."adventures" SET "map_type" = 'FORTRESS' WHERE "name" = 'fortress';
UPDATE "public"."adventures" SET "map_type" = 'GATE' WHERE "name" = 'gate';

-- The client filters cards by what they put on the field: unit (Spawn), building (Summon),
-- drop, explosion and shot. Four player magics still carry the legacy 'Code' cast kind, which
-- only meant "implemented in custom code" and says nothing about what the card does, so they
-- would fall out of every filter. Give each the kind that matches what it casts.
--
--   tower, cannon       put down a building          -> Summon
--   wind_blade          fires a projectile           -> Shot
--   wind_explosion      bursts where it is cast      -> Explosion
--
-- The game server never reads cast_kind. In the lobby, only RandomDeckCandidateRepository
-- does, and it keys on 'Spawn', which none of these rows are or become.
-- no-tags: this migration registers neither a game object nor a magic.

UPDATE "public"."magics" SET "cast_kind" = 'Summon'
WHERE "name" IN ('tower', 'cannon') AND "cast_kind" = 'Code';

UPDATE "public"."magics" SET "cast_kind" = 'Shot'
WHERE "name" = 'wind_blade' AND "cast_kind" = 'Code';

UPDATE "public"."magics" SET "cast_kind" = 'Explosion'
WHERE "name" = 'wind_explosion' AND "cast_kind" = 'Code';

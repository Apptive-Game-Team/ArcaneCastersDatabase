-- Bots pick which emote to reach for, and how often, from a temperament that is independent
-- of skill: tier and counter_aggression tune difficulty, temperament tunes personality only,
-- and changing one must never change the other.
-- no-tags: this migration registers neither a game object nor a magic.

CREATE TYPE "public"."bot_temperament" AS ENUM (
    'WARM',
    'SMUG',
    'TIMID',
    'STOIC'
);

ALTER TABLE "public"."bot_personas"
    ADD COLUMN "temperament" "public"."bot_temperament" NOT NULL DEFAULT 'WARM';

-- The 45 concept bots seeded by the old chain's V030_20260712__seed_concept_bots.sql (now
-- folded into V001_20260916__baseline.sql) are 9 concepts by 5 tiers. Concept is not stored
-- as a column anywhere in the schema; bot_personas.name is the only surviving trace, so the
-- family lists below are copied verbatim from that migration's tier_names arrays. Every tier
-- of a concept gets the same temperament -- temperament tracks concept character, never tier
-- or counter_aggression.
--
--   Emperor of the Skies (Skies)   -> STOIC  aloof sky sovereign, speaks rarely
--   Magma Maniac (Magma)           -> SMUG   cackles at its own eruptions, mocking
--   Face Hunter (Face)             -> SMUG   rushdown brawler that trash-talks every hit
--   Minion Master (Minions)        -> STOIC  lets the horde do the talking
--   Grass Gym Leader (Grass)       -> WARM   welcomes every challenger
--   Shock Supreme (Shock)          -> TIMID  jumps at its own sparks
--   Water Bomb Maniac (Water Bomb) -> WARM   giggly and splashy, plays rather than menaces
--   Summoner (Summoner)            -> TIMID  nervous about the rifts it opens
--   Golem Summoner (Golems)        -> STOIC  silent stone, its constructs speak for it
--
-- Grass Gym Leader and Water Bomb Maniac keep the column default 'WARM' explicitly below, so
-- every concept is accounted for in this file rather than relying on the default silently.
-- Any bot outside these 45 (present or future) also keeps the 'WARM' default, on purpose.

UPDATE bot_personas SET temperament = 'STOIC' WHERE name IN (
    'Sky Hatchling', 'Cloud Cadet', 'Storm Captain', 'Tempest Regent', 'Celestial Emperor',
    'Tiny Wrangler', 'Swarm Keeper', 'Minion Tactician', 'Horde Commander', 'Minion Master',
    'Pebble Caller', 'Minirock Keeper', 'Stone Shaper', 'Golem Architect', 'Colossus Summoner'
);

UPDATE bot_personas SET temperament = 'SMUG' WHERE name IN (
    'Ember Tinkerer', 'Lava Enthusiast', 'Magma Addict', 'Caldera Fanatic', 'Volcanic Maniac',
    'Reckless Rookie', 'Face Rusher', 'Relentless Striker', 'Lethal Hunter', 'Facebreaker'
);

UPDATE bot_personas SET temperament = 'TIMID' WHERE name IN (
    'Static Spark', 'Volt Rookie', 'Thunder Charger', 'Lightning Ace', 'Shock Supreme',
    'Novice Caller', 'Familiar Keeper', 'Spirit Invoker', 'Rift Conjurer', 'Grand Summoner'
);

UPDATE bot_personas SET temperament = 'WARM' WHERE name IN (
    'Sprout Scout', 'Vine Trainer', 'Grove Keeper', 'Verdant Captain', 'Grass Gym Leader',
    'Splash Rookie', 'Bubble Bomber', 'Torrent Blaster', 'Tidal Demolitionist', 'Water Bomb Maniac'
);

DO $$
DECLARE
    missing text;
BEGIN
    SELECT string_agg(expected.name, ', ' ORDER BY expected.name)
    INTO missing
    FROM (VALUES
        ('Sky Hatchling'), ('Cloud Cadet'), ('Storm Captain'), ('Tempest Regent'), ('Celestial Emperor'),
        ('Ember Tinkerer'), ('Lava Enthusiast'), ('Magma Addict'), ('Caldera Fanatic'), ('Volcanic Maniac'),
        ('Reckless Rookie'), ('Face Rusher'), ('Relentless Striker'), ('Lethal Hunter'), ('Facebreaker'),
        ('Tiny Wrangler'), ('Swarm Keeper'), ('Minion Tactician'), ('Horde Commander'), ('Minion Master'),
        ('Sprout Scout'), ('Vine Trainer'), ('Grove Keeper'), ('Verdant Captain'), ('Grass Gym Leader'),
        ('Static Spark'), ('Volt Rookie'), ('Thunder Charger'), ('Lightning Ace'), ('Shock Supreme'),
        ('Splash Rookie'), ('Bubble Bomber'), ('Torrent Blaster'), ('Tidal Demolitionist'), ('Water Bomb Maniac'),
        ('Novice Caller'), ('Familiar Keeper'), ('Spirit Invoker'), ('Rift Conjurer'), ('Grand Summoner'),
        ('Pebble Caller'), ('Minirock Keeper'), ('Stone Shaper'), ('Golem Architect'), ('Colossus Summoner')
    ) AS expected(name)
    WHERE NOT EXISTS (
        SELECT 1 FROM bot_personas bp WHERE bp.name = expected.name
    );

    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'Missing expected concept bots, temperament assignment incomplete for: %', missing;
    END IF;
END $$;

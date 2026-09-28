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
-- family lists below are copied verbatim from that migration's tier_names arrays, in ladder
-- order from rookie to elite.
--
-- Each family leans toward one temperament, but every family has at least one tier that reads
-- differently from the rest: a nervous rookie who hasn't grown into the family's character
-- yet, a veteran who has gone quiet, or a tier that has picked up an edge the rest of the
-- family lacks. This is authored by hand from each bot's name, never derived from tier or
-- counter_aggression -- the ladder only informed which tier plays against type.
--
--   Emperor of the Skies (Skies), leans STOIC -- aloof sky sovereign, speaks rarely
--     Sky Hatchling      TIMID  a fledgling, easily startled, hasn't grown composed yet
--     Cloud Cadet        STOIC
--     Storm Captain      STOIC
--     Tempest Regent     STOIC
--     Celestial Emperor  STOIC
--
--   Magma Maniac (Magma), leans SMUG -- cackles at its own eruptions, mocking
--     Ember Tinkerer     TIMID  a nervous rookie who hasn't caught the family's swagger yet
--     Lava Enthusiast    SMUG
--     Magma Addict       SMUG
--     Caldera Fanatic    SMUG
--     Volcanic Maniac    SMUG
--
--   Face Hunter (Face), leans SMUG -- rushdown brawler that trash-talks every hit
--     Reckless Rookie     WARM  green and eager, hasn't learned to taunt yet
--     Face Rusher         SMUG
--     Relentless Striker  SMUG
--     Lethal Hunter       SMUG
--     Facebreaker         SMUG
--
--   Minion Master (Minions), leans WARM -- friendly commander, cheers its horde on
--     Tiny Wrangler      WARM
--     Swarm Keeper       WARM
--     Minion Tactician   WARM
--     Horde Commander    WARM
--     Minion Master      STOIC  the veteran namesake has gone quiet, lets the horde talk
--
--   Grass Gym Leader (Grass), leans WARM -- welcomes every challenger
--     Sprout Scout       WARM
--     Vine Trainer       WARM
--     Grove Keeper       STOIC  tends the grove alone, says little
--     Verdant Captain    WARM
--     Grass Gym Leader   WARM
--
--   Shock Supreme (Shock), leans TIMID -- jumps at its own sparks
--     Static Spark       TIMID
--     Volt Rookie        TIMID
--     Thunder Charger    SMUG   enough voltage now to feel cocky about it
--     Lightning Ace      TIMID
--     Shock Supreme      TIMID  still rattled by its own power, even at the top
--
--   Water Bomb Maniac (Water Bomb), leans WARM -- giggly and splashy, plays rather than menaces
--     Splash Rookie        WARM
--     Bubble Bomber        WARM
--     Torrent Blaster      SMUG  bigger blasts, bigger taunts
--     Tidal Demolitionist  WARM
--     Water Bomb Maniac    SMUG  the playful splashing has curdled into gloating by the top
--
--   Summoner (Summoner), leans TIMID -- nervous about the rifts it opens
--     Novice Caller      TIMID
--     Familiar Keeper    WARM   bonds warmly with its one small familiar
--     Spirit Invoker     TIMID
--     Rift Conjurer      TIMID
--     Grand Summoner     STOIC  has mastered the fear into quiet composure
--
--   Golem Summoner (Golems), leans STOIC -- silent stone, its constructs speak for it
--     Pebble Caller      WARM   still a cheerful kid rolling pebbles around
--     Minirock Keeper    STOIC
--     Stone Shaper       STOIC
--     Golem Architect    STOIC
--     Colossus Summoner  STOIC
--
-- Totals across the 45: WARM 14, SMUG 11, TIMID 9, STOIC 11.
--
-- The 13 bots outside these families (present or future) keep the column default 'WARM'.

UPDATE bot_personas SET temperament = 'WARM' WHERE name IN (
    'Reckless Rookie',
    'Tiny Wrangler', 'Swarm Keeper', 'Minion Tactician', 'Horde Commander',
    'Sprout Scout', 'Vine Trainer', 'Verdant Captain', 'Grass Gym Leader',
    'Splash Rookie', 'Bubble Bomber', 'Tidal Demolitionist',
    'Familiar Keeper',
    'Pebble Caller'
);

UPDATE bot_personas SET temperament = 'SMUG' WHERE name IN (
    'Lava Enthusiast', 'Magma Addict', 'Caldera Fanatic', 'Volcanic Maniac',
    'Face Rusher', 'Relentless Striker', 'Lethal Hunter', 'Facebreaker',
    'Thunder Charger',
    'Torrent Blaster', 'Water Bomb Maniac'
);

UPDATE bot_personas SET temperament = 'TIMID' WHERE name IN (
    'Sky Hatchling',
    'Ember Tinkerer',
    'Static Spark', 'Volt Rookie', 'Lightning Ace', 'Shock Supreme',
    'Novice Caller', 'Spirit Invoker', 'Rift Conjurer'
);

UPDATE bot_personas SET temperament = 'STOIC' WHERE name IN (
    'Cloud Cadet', 'Storm Captain', 'Tempest Regent', 'Celestial Emperor',
    'Minion Master',
    'Grove Keeper',
    'Grand Summoner',
    'Minirock Keeper', 'Stone Shaper', 'Golem Architect', 'Colossus Summoner'
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

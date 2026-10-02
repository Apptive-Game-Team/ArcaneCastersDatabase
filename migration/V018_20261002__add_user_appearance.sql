-- 사용자마다 경기에서 다른 플레이어 외형을 보여 주기 위해 users.appearance 를 추가한다.
-- 값은 client 의 Resources/PlayerAppearances/ 아래 디렉터리 이름이고, 'default' 는 모든
-- 사용자가 처음에 가지는 외형이다. 기존 행은 전부 'default' 가 된다.
--
-- 컬럼은 users 에 둔다. 봇만이 아니라 사람 플레이어도 나중에 외형을 가질 수 있어야 하기
-- 때문이다. 허용 값을 CHECK 로 막지 않는다. 사용자가 쓸 수 있는 외형은 계속 늘어나고 어떤
-- 외형을 가졌는지는 application 이 정하므로, CHECK 를 두면 외형이 늘 때마다 migration 이
-- 필요하다.
--
-- 지금 채우는 값은 storm, blaze, summoner, golem, grass, tide 여섯 가지다. 컨셉 아홉 개를
-- 여섯 외형으로 묶는다.
--
--   storm     Emperor of the Skies, Shock Supreme   10마리
--   blaze     Magma Maniac, Face Hunter             10마리
--   summoner  Minion Master, Summoner               10마리
--   golem     Golem Summoner                         5마리
--   grass     Grass Gym Leader                       5마리
--   tide      Water Bomb Maniac                      5마리
--
-- 컨셉은 컬럼으로 저장되어 있지 않아서 V010_20260922__add_bot_temperament.sql 처럼
-- bot_personas.name 으로 대응시키고, bot_personas.user_id 로 users 행을 찾는다. 사람 플레이어,
-- 접대 봇 'Warm Welcome', enabled = false 인 옛 봇은 'default' 로 남는다.
--
-- lobby 는 이 migration 이 적용된 뒤에 배포한다. 이 컬럼을 읽는 lobby 가 먼저 뜨면 쿼리가
-- 실패한다.
-- no-tags: this migration registers neither a game object nor a magic.

ALTER TABLE "public"."users"
    ADD COLUMN IF NOT EXISTS "appearance" character varying(32) NOT NULL DEFAULT 'default';

UPDATE users SET appearance = 'storm' WHERE id IN (
    SELECT user_id FROM bot_personas WHERE name IN (
    'Sky Hatchling', 'Cloud Cadet', 'Storm Captain', 'Tempest Regent', 'Celestial Emperor',
    'Static Spark', 'Volt Rookie', 'Thunder Charger', 'Lightning Ace', 'Shock Supreme'
));

UPDATE users SET appearance = 'blaze' WHERE id IN (
    SELECT user_id FROM bot_personas WHERE name IN (
    'Ember Tinkerer', 'Lava Enthusiast', 'Magma Addict', 'Caldera Fanatic', 'Volcanic Maniac',
    'Reckless Rookie', 'Face Rusher', 'Relentless Striker', 'Lethal Hunter', 'Facebreaker'
));

UPDATE users SET appearance = 'summoner' WHERE id IN (
    SELECT user_id FROM bot_personas WHERE name IN (
    'Tiny Wrangler', 'Swarm Keeper', 'Minion Tactician', 'Horde Commander', 'Minion Master',
    'Novice Caller', 'Familiar Keeper', 'Spirit Invoker', 'Rift Conjurer', 'Grand Summoner'
));

UPDATE users SET appearance = 'golem' WHERE id IN (
    SELECT user_id FROM bot_personas WHERE name IN (
    'Pebble Caller', 'Minirock Keeper', 'Stone Shaper', 'Golem Architect', 'Colossus Summoner'
));

UPDATE users SET appearance = 'grass' WHERE id IN (
    SELECT user_id FROM bot_personas WHERE name IN (
    'Sprout Scout', 'Vine Trainer', 'Grove Keeper', 'Verdant Captain', 'Grass Gym Leader'
));

UPDATE users SET appearance = 'tide' WHERE id IN (
    SELECT user_id FROM bot_personas WHERE name IN (
    'Splash Rookie', 'Bubble Bomber', 'Torrent Blaster', 'Tidal Demolitionist', 'Water Bomb Maniac'
));

DO $$
DECLARE
    assigned integer;
    null_count integer;
    storm_count integer;
    blaze_count integer;
    summoner_count integer;
    golem_count integer;
    grass_count integer;
    tide_count integer;
    default_count integer;
    total integer;
BEGIN
    SELECT count(*) FILTER (WHERE appearance IS NULL),
           count(*) FILTER (WHERE appearance <> 'default'),
           count(*) FILTER (WHERE appearance = 'storm'),
           count(*) FILTER (WHERE appearance = 'blaze'),
           count(*) FILTER (WHERE appearance = 'summoner'),
           count(*) FILTER (WHERE appearance = 'golem'),
           count(*) FILTER (WHERE appearance = 'grass'),
           count(*) FILTER (WHERE appearance = 'tide'),
           count(*) FILTER (WHERE appearance = 'default'),
           count(*)
    INTO null_count, assigned, storm_count, blaze_count, summoner_count, golem_count, grass_count, tide_count,
         default_count, total
    FROM users;

    IF null_count <> 0 THEN
        RAISE EXCEPTION 'Expected no users with a NULL appearance, found %', null_count;
    END IF;

    IF assigned <> 45 THEN
        RAISE EXCEPTION 'Expected 45 users with a non-default appearance, found %', assigned;
    END IF;

    IF storm_count <> 10 OR blaze_count <> 10 OR summoner_count <> 10
        OR golem_count <> 5 OR grass_count <> 5 OR tide_count <> 5 THEN
        RAISE EXCEPTION 'Appearance split is wrong: storm %, blaze %, summoner %, golem %, grass %, tide % (expected 10/10/10/5/5/5)',
            storm_count, blaze_count, summoner_count, golem_count, grass_count, tide_count;
    END IF;

    IF default_count <> total - 45 THEN
        RAISE EXCEPTION 'Expected every other user to have the default appearance, found % of %', default_count, total - 45;
    END IF;
END $$;

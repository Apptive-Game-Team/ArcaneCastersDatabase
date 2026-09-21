-- 카드 등급별로 마법 70개의 mana_cost 를 다시 매긴다.
--
-- 등급은 옛 word 체계의 magic_cards recipe 에서 가져왔다. 그 표는 magic-card 개편 때 사라졌지만
-- 마법 하나를 만들 때 카드를 몇 장 썼는지가 그 마법의 무게를 그대로 나타내므로, 장수를 그대로
-- 등급으로 쓴다. 지금 값은 20 에서 60 사이에 몰려 있어서 2장짜리와 5장짜리의 차이가 3배밖에 안 된다.
--
--   2장 28개 -> 10, 15
--   3장 28개 -> 20 ~ 40
--   4장  6개 -> 30 ~ 50
--   5장  8개 -> 70, 80
--
-- 구간 안에서는 소환수가 위쪽, 직접 피해를 주는 마법이 아래쪽이다. 건물과 토템은 그 사이에 둔다.
-- 같은 종류끼리는 hp, damage, duration 과 마법마다 다른 동작을 보고 나눴다. 각 묶음의 이유는
-- 아래 주석에 적는다.
--
-- recipe 가 없는 6개(pve_nature_slime_nest, water_slime_nest, fire_slime_nest, lightning_shot,
-- water_shot, wind_explosion)는 PvE 와 옛 기본 마법이고 mana 가 0 이다. 이 파일은 건드리지 않는다.
--
-- mana_cost 는 magics.name 과 같은 이름의 game_objects 행에 붙어 있고, game server 와 lobby 가
-- 둘 다 그 이름으로 읽는다(MagicInputHandler.parameterKey, MagicQueryRepository). 행이 없으면
-- Parameters.getValue 가 예외를 던져 경기가 그 자리에서 끝나므로, 이 파일은 update 만 한다.
--
-- no-tags: magics 와 game_objects 에 새 행을 넣지 않는다. 기존 행의 값만 바꾼다.

CREATE TEMP TABLE mana_tier (
    magic_name text PRIMARY KEY,
    card_count  integer     NOT NULL,
    mana_cost   integer     NOT NULL
) ON COMMIT DROP;

INSERT INTO mana_tier(magic_name, card_count, mana_cost)
VALUES
    -- 2장 28개. 던지면 그 자리에서 끝나는 마법 15개가 10 이다.
    ('magma_explosion', 2, 10),
    ('leafair', 2, 10),
    ('lightning_drop', 2, 10),
    ('water_explosion', 2, 10),
    ('lightning_explosion', 2, 10),
    ('sand_storm', 2, 10),
    ('overgrowth', 2, 10),
    ('razor_gale', 2, 10),
    ('rock_drop', 2, 10),
    ('fire_shot', 2, 10),
    ('chain_lightning', 2, 10),
    ('tide_call', 2, 10),
    ('rock_rolling', 2, 10),
    ('wind_blade', 2, 10),
    ('vine_toss', 2, 10),
    -- 2장 소환 13개는 15 다. 필드에 몸이 남아서 상대가 따로 부숴야 사라진다. 건물 6개는
    -- duration 동안 계속 일하고(electric_tower 20초 hp 160, bubble_generator 12초 hp 180),
    -- 소환수 7개는 hp 20 에서 150 짜리 몸이 1마리에서 5마리까지 나온다. chicken_commando 는
    -- cast_kind 가 Drop 이지만 hp 120 damage 30 짜리 몸을 떨어뜨리므로 여기 둔다.
    ('life_tree', 2, 15),
    ('bubble_generator', 2, 15),
    ('rallying_totem', 2, 15),
    ('rock_turret', 2, 15),
    ('electric_tower', 2, 15),
    ('wind_totem', 2, 15),
    ('ember_spirit_swarm', 2, 15),
    ('mini_rock_swarm', 2, 15),
    ('seed_spirit_swarm', 2, 15),
    ('water_slime_swarm', 2, 15),
    ('wind_spirit', 2, 15),
    ('zap_mouse', 2, 15),
    ('chicken_commando', 2, 15),

    -- 3장, 직접 마법 4개. 20 이 한 점을 때리는 쪽, 25 가 큰 한 방이다.
    -- shock_overload 는 damage 80 에 radius 0.5, frenzy_totem 은 피해가 없고 10초짜리 공격속도
    -- 버프라 이미 깔린 아군이 있어야 값을 한다.
    ('shock_overload', 3, 20),
    ('frenzy_totem', 3, 20),
    -- boulder_strike 는 damage 140 에 sub_damage 200 과 push_force 7, tidal_warhead 는
    -- damage 240 을 radius 2.5 로 편다. 3장짜리 중 한 번에 가장 크게 때린다.
    ('boulder_strike', 3, 25),
    ('tidal_warhead', 3, 25),

    -- 3장, 건물과 토템 14개. 지원용 5개가 30, 스스로 싸우거나 판을 바꾸는 9개가 35 다.
    ('healing_totem', 3, 30),
    ('repair_totem', 3, 30),
    ('firework_tower', 3, 30),
    ('seed_nest', 3, 30),
    ('grass_generator', 3, 30),
    -- mana_well 은 mana 를 되돌려 주므로 싸게 두면 무조건 넣는 카드가 된다. shock_trap 은
    -- stun_duration 10, dragon_tower 는 attack_range 18 로 필드 전체를 덮는다. cannon 과 tower 는
    -- hp 450/400 에 damage 100/120, titan_remnant 와 vine_colony 는 hp 400 이다.
    ('mana_well', 3, 35),
    ('crater', 3, 35),
    ('vine_colony', 3, 35),
    ('titan_remnant', 3, 35),
    ('dragon_tower', 3, 35),
    ('towerback', 3, 35),
    ('shock_trap', 3, 35),
    ('tower', 3, 35),
    ('cannon', 3, 35),

    -- 3장, 소환수 10개. hp 200대의 견제형 5개가 35, 벽이 되거나 원거리로 때리는 5개가 40 이다.
    ('storm_rider', 3, 35),
    ('thunder_spirit', 3, 35),
    ('bubble_spirit', 3, 35),
    ('tree_golem', 3, 35),
    ('thunder_bird_swarm', 3, 35),
    -- rock_golem 은 hp 1000, fire_spirit 은 hp 350 에 광역 공격, aqua_archer 는 hp 300 에
    -- damage 100 을 attack_range 5 에서, rock_mage 는 한 번에 2발, vine_spirit 은 hp 280 짜리 2마리다.
    ('fire_spirit', 3, 40),
    ('rock_golem', 3, 40),
    ('aqua_archer', 3, 40),
    ('rock_mage', 3, 40),
    ('vine_spirit', 3, 40),

    -- 4장 6개. 마법 2개가 40, 소환수 4개가 45 와 50 이다.
    -- will_o_wisp 는 적 하나를 빼앗고(MindControlShot), spirit_bomb 은 아군 체력을 빨아
    -- 그 비율만큼 때린다(SpiritBombChannel). 둘 다 판에 무언가 있어야 값을 한다.
    ('will_o_wisp', 4, 40),
    ('spirit_bomb', 4, 40),
    -- bomb_sprite 는 hp 200 짜리 자폭, wall_golem 은 hp 1750 에 speed 0.3 이라 벽으로만 쓴다.
    ('bomb_sprite', 4, 45),
    ('wall_golem', 4, 45),
    -- dimension_toad 는 spawn_interval 5 로 계속 불어나고, magma_spirit 은 hp 1750 에
    -- damage 80 을 광역으로 때린다. 4장 중 혼자 남아도 이기는 둘이다.
    ('dimension_toad', 4, 50),
    ('magma_spirit', 4, 50),

    -- 5장 8개. 한 번 쓰고 사라지는 마법 3개가 70, 필드에 남는 소환수 5개가 80 이다.
    ('meteor_shower', 5, 70),
    ('vine_world', 5, 70),
    ('tornado_strike', 5, 70),
    ('evil_ent', 5, 80),
    ('cloud_dragon', 5, 80),
    ('storm_stag', 5, 80),
    ('fire_lord_spirit', 5, 80),
    ('sea_serpent', 5, 80);

-- 이름이 하나라도 어긋나면 그 마법만 조용히 옛 값으로 남는다. 먼저 막는다.
DO
$$
    DECLARE
        missing text;
    BEGIN
        SELECT string_agg(tier.magic_name, ', ' ORDER BY tier.magic_name)
        INTO missing
        FROM mana_tier tier
        WHERE NOT EXISTS (SELECT 1
                          FROM magics magic
                                   JOIN game_objects object ON object.name = magic.name
                                   JOIN parameter_values stored ON stored.game_object_id = object.id
                                   JOIN parameters parameter ON parameter.id = stored.parameter_id
                              AND parameter.name = 'mana_cost'
                          WHERE magic.name = tier.magic_name);

        IF missing IS NOT NULL THEN
            RAISE EXCEPTION 'mana_cost row missing for: %', missing;
        END IF;
    END
$$;

-- value 가 이미 같으면 아무것도 바꾸지 않는다. 그래서 다시 돌려도 updated_at 이 또 올라가지 않는다
-- (migration rule 3).
--
-- magics.updated_at 을 같이 올린다. lobby 의 MagicDataService 는 magic 목록의 version 을
-- max(magics.updated_at) 으로 만들고 mana 값은 parameter_values 에서 join 해 온다. 여기를 안 올리면
-- 이미 목록을 받아 둔 client 는 version 이 그대로라 옛 mana 를 계속 보여 준다.
WITH changed AS (
    UPDATE parameter_values stored
        SET value = tier.mana_cost,
            updated_at = now()
        FROM mana_tier tier
            JOIN game_objects object ON object.name = tier.magic_name
            JOIN parameters parameter ON parameter.name = 'mana_cost'
        WHERE stored.game_object_id = object.id
            AND stored.parameter_id = parameter.id
            AND stored.value IS DISTINCT FROM tier.mana_cost::double precision
        RETURNING tier.magic_name)
UPDATE magics magic
SET updated_at = now()
FROM changed
WHERE magic.name = changed.magic_name;

-- 끝난 뒤 70개가 전부 표대로인지 확인한다.
DO
$$
    DECLARE
        wrong text;
    BEGIN
        SELECT string_agg(format('%s=%s(expected %s)', tier.magic_name, stored.value, tier.mana_cost),
                          ', ' ORDER BY tier.magic_name)
        INTO wrong
        FROM mana_tier tier
                 JOIN game_objects object ON object.name = tier.magic_name
                 JOIN parameters parameter ON parameter.name = 'mana_cost'
                 JOIN parameter_values stored ON stored.game_object_id = object.id
            AND stored.parameter_id = parameter.id
        WHERE stored.value IS DISTINCT FROM tier.mana_cost::double precision;

        IF wrong IS NOT NULL THEN
            RAISE EXCEPTION 'mana_cost not applied for: %', wrong;
        END IF;

        RAISE NOTICE '% magics now carry a card-tier mana cost', (SELECT count(*) FROM mana_tier);
    END
$$;

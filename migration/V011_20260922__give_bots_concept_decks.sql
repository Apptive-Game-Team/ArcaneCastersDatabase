-- 봇 45마리와 접대 봇이 전부 같은 덱 15장을 들고 있었다. 카드 시대의 덱을 마법 기준으로 다시
-- 만든 V086_20260908__move_ownership_and_decks_to_magics.sql (지금은
-- V001_20260916__baseline.sql 에 접혀 있다) 이 모든 덱을 기본 덱 하나로 덮어썼고, decks.name 의
-- 'Skies · INTRO' 같은 이름만 계열과 tier 의 흔적으로 남았다. BotBrain 은 손패에 들어온 카드를
-- mana 당 가치로 줄 세워 고르므로, 덱이 같으면 아홉 계열이 같은 경기를 한다.
--
-- 계열이 정체성을 정하고 tier 가 값의 상한을 정한다. 계열은 그 이름에 맞는 원소와 cast kind 의
-- 마법만 쓰고, tier 가 오를수록 비싼 핵심 마법이 열리면서 장당 평균 mana 가 오른다. 봇의 사고
-- 속도와 counter_aggression 은 bot_personas 가 그대로 쥐고 있으므로, 이 파일은 무엇을 쥐고
-- 싸우는지만 바꾼다.
--
-- 덱마다 지키는 규칙은 파일 끝의 DO 블록이 검사한다.
--
--   1. 정확히 15장, 같은 마법 3장 이하. DeckValidator.DECK_CARD_COUNT 와 같은 수다.
--   2. purpose = 'PLAYER' 인 마법만. LEGACY 6종과 PVE 1종은 덱에 들어가지 않는다.
--   3. mana_cost 가 있는 마법만. 없으면 BotSpellStats 가 UNKNOWN_MANA_COST 9999 를 매겨
--      그 카드는 한 번도 시전되지 않는다.
--   4. 15장 중 8장 이상이 cast_kind 가 'Summon' 이거나 'Spawn'. BotBrain.buildPlay 는 소환이
--      아닌 카드를 적 유닛 위에서만 채점하므로, 공격 마법만 든 덱은 상대 판이 비면 멈춘다.
--   5. 한 계열 안에서 tier 가 오를수록 장당 평균 mana 가 오른다.
--   6. 봇이 덱에 든 마법을 그만큼 가지고 있다. user_magics 는 지금 덱과 어긋난 10종을 들고
--      있어서, 봇이 자기 것이 아닌 카드를 덱에 넣은 상태였다.
--
-- 접대 봇 'Warm Welcome' 은 15장 전부 소환이라 규칙 4의 예외다. HospitalityDirector 가 소환이
-- 아닌 카드를 건너뛰므로 공격 마법을 넣으면 그 자리가 죽은 카드가 된다. 가장 싼 몸 다섯 종을
-- 3장씩 넣어, 플레이어 판보다 약한 것만 계속 내놓게 한다.
--
-- no-tags: this migration registers neither a game object nor a magic.

CREATE TEMP TABLE bot_deck_seed (
    deck_name VARCHAR(31) NOT NULL,
    magic_name VARCHAR(255) NOT NULL,
    copies INTEGER NOT NULL,
    PRIMARY KEY (deck_name, magic_name)
) ON COMMIT DROP;

-- 계열별 정체성:
--   Skies       Wind + Lightning 의 나는 유닛. 싸고 빠른 몸으로 판을 채우고 번개로 정리한다.
--   Magma       Fire + Rock 의 건물과 낙하. 탑을 세워 두고 폭발로 압박한다.
--   Face        Fire + Lightning 의 직격. 사거리 18짜리 값싼 공격 마법으로 얼굴을 때린다.
--   Minions     Lightning + Nature 의 작은 몸 다수. 알을 까는 건물과 싼 소환이 중심이다.
--   Grass       Nature + Wind 의 자연. 회복과 덩굴로 버티다 큰 나무로 굳힌다.
--   Shock       Lightning + Water 의 감전. 탑과 함정으로 묶고 과부하로 터뜨린다.
--   Water Bomb  Water + Wind 의 폭탄. 물 폭발과 탄두를 쌓아 한 번에 크게 터뜨린다.
--   Summoner    Lightning + Nature 의 큰 몸. 알을 까는 건물과 mana_well 로 비싼 소환을 받친다.
--   Golems      Rock + Fire 의 덩치. 단단한 몸을 줄줄이 세우고 돌로 마무리한다.
INSERT INTO bot_deck_seed(deck_name, magic_name, copies) VALUES
    -- Skies
        ('Skies · INTRO', 'lightning_drop', 3),
        ('Skies · INTRO', 'razor_gale', 3),
        ('Skies · INTRO', 'electric_tower', 3),
        ('Skies · INTRO', 'wind_spirit', 3),
        ('Skies · INTRO', 'wind_totem', 3),
        ('Skies · BEGINNER', 'lightning_drop', 3),
        ('Skies · BEGINNER', 'razor_gale', 3),
        ('Skies · BEGINNER', 'electric_tower', 2),
        ('Skies · BEGINNER', 'wind_spirit', 3),
        ('Skies · BEGINNER', 'wind_totem', 2),
        ('Skies · BEGINNER', 'thunder_bird_swarm', 2),
        ('Skies · INTERMEDIATE', 'chain_lightning', 3),
        ('Skies · INTERMEDIATE', 'razor_gale', 2),
        ('Skies · INTERMEDIATE', 'wind_spirit', 3),
        ('Skies · INTERMEDIATE', 'wind_totem', 2),
        ('Skies · INTERMEDIATE', 'thunder_bird_swarm', 2),
        ('Skies · INTERMEDIATE', 'thunder_spirit', 3),
        ('Skies · ADVANCED', 'chain_lightning', 2),
        ('Skies · ADVANCED', 'razor_gale', 2),
        ('Skies · ADVANCED', 'wind_spirit', 2),
        ('Skies · ADVANCED', 'wind_totem', 2),
        ('Skies · ADVANCED', 'thunder_bird_swarm', 2),
        ('Skies · ADVANCED', 'thunder_spirit', 3),
        ('Skies · ADVANCED', 'bomb_sprite', 2),
        ('Skies · ELITE', 'chain_lightning', 2),
        ('Skies · ELITE', 'razor_gale', 2),
        ('Skies · ELITE', 'wind_spirit', 2),
        ('Skies · ELITE', 'thunder_bird_swarm', 2),
        ('Skies · ELITE', 'thunder_spirit', 3),
        ('Skies · ELITE', 'bomb_sprite', 2),
        ('Skies · ELITE', 'cloud_dragon', 2),
    -- Magma
        ('Magma · INTRO', 'magma_explosion', 3),
        ('Magma · INTRO', 'rock_drop', 3),
        ('Magma · INTRO', 'ember_spirit_swarm', 3),
        ('Magma · INTRO', 'rallying_totem', 3),
        ('Magma · INTRO', 'rock_turret', 3),
        ('Magma · BEGINNER', 'magma_explosion', 3),
        ('Magma · BEGINNER', 'ember_spirit_swarm', 3),
        ('Magma · BEGINNER', 'rallying_totem', 2),
        ('Magma · BEGINNER', 'rock_turret', 3),
        ('Magma · BEGINNER', 'frenzy_totem', 2),
        ('Magma · BEGINNER', 'firework_tower', 2),
        ('Magma · INTERMEDIATE', 'magma_explosion', 2),
        ('Magma · INTERMEDIATE', 'ember_spirit_swarm', 3),
        ('Magma · INTERMEDIATE', 'rallying_totem', 2),
        ('Magma · INTERMEDIATE', 'frenzy_totem', 2),
        ('Magma · INTERMEDIATE', 'firework_tower', 2),
        ('Magma · INTERMEDIATE', 'crater', 2),
        ('Magma · INTERMEDIATE', 'dragon_tower', 2),
        ('Magma · ADVANCED', 'magma_explosion', 2),
        ('Magma · ADVANCED', 'rock_drop', 1),
        ('Magma · ADVANCED', 'ember_spirit_swarm', 2),
        ('Magma · ADVANCED', 'rallying_totem', 2),
        ('Magma · ADVANCED', 'crater', 2),
        ('Magma · ADVANCED', 'dragon_tower', 2),
        ('Magma · ADVANCED', 'titan_remnant', 2),
        ('Magma · ADVANCED', 'magma_spirit', 2),
        ('Magma · ELITE', 'magma_explosion', 2),
        ('Magma · ELITE', 'rock_drop', 1),
        ('Magma · ELITE', 'ember_spirit_swarm', 2),
        ('Magma · ELITE', 'crater', 2),
        ('Magma · ELITE', 'dragon_tower', 2),
        ('Magma · ELITE', 'titan_remnant', 2),
        ('Magma · ELITE', 'magma_spirit', 2),
        ('Magma · ELITE', 'meteor_shower', 2),
    -- Face
        ('Face · INTRO', 'fire_shot', 3),
        ('Face · INTRO', 'magma_explosion', 3),
        ('Face · INTRO', 'ember_spirit_swarm', 3),
        ('Face · INTRO', 'rallying_totem', 3),
        ('Face · INTRO', 'zap_mouse', 3),
        ('Face · BEGINNER', 'chain_lightning', 2),
        ('Face · BEGINNER', 'fire_shot', 3),
        ('Face · BEGINNER', 'ember_spirit_swarm', 3),
        ('Face · BEGINNER', 'rallying_totem', 2),
        ('Face · BEGINNER', 'zap_mouse', 3),
        ('Face · BEGINNER', 'shock_overload', 2),
        ('Face · INTERMEDIATE', 'chain_lightning', 2),
        ('Face · INTERMEDIATE', 'fire_shot', 3),
        ('Face · INTERMEDIATE', 'ember_spirit_swarm', 2),
        ('Face · INTERMEDIATE', 'rallying_totem', 2),
        ('Face · INTERMEDIATE', 'zap_mouse', 2),
        ('Face · INTERMEDIATE', 'shock_overload', 2),
        ('Face · INTERMEDIATE', 'thunder_bird_swarm', 2),
        ('Face · ADVANCED', 'chain_lightning', 2),
        ('Face · ADVANCED', 'fire_shot', 3),
        ('Face · ADVANCED', 'ember_spirit_swarm', 2),
        ('Face · ADVANCED', 'zap_mouse', 2),
        ('Face · ADVANCED', 'shock_overload', 2),
        ('Face · ADVANCED', 'thunder_bird_swarm', 2),
        ('Face · ADVANCED', 'fire_spirit', 2),
        ('Face · ELITE', 'chain_lightning', 2),
        ('Face · ELITE', 'fire_shot', 3),
        ('Face · ELITE', 'zap_mouse', 2),
        ('Face · ELITE', 'shock_overload', 2),
        ('Face · ELITE', 'thunder_bird_swarm', 2),
        ('Face · ELITE', 'fire_spirit', 2),
        ('Face · ELITE', 'dimension_toad', 2),
    -- Minions
        ('Minions · INTRO', 'leafair', 3),
        ('Minions · INTRO', 'lightning_drop', 3),
        ('Minions · INTRO', 'life_tree', 3),
        ('Minions · INTRO', 'seed_nest', 3),
        ('Minions · INTRO', 'zap_mouse', 3),
        ('Minions · BEGINNER', 'leafair', 3),
        ('Minions · BEGINNER', 'lightning_drop', 2),
        ('Minions · BEGINNER', 'life_tree', 2),
        ('Minions · BEGINNER', 'seed_nest', 3),
        ('Minions · BEGINNER', 'zap_mouse', 3),
        ('Minions · BEGINNER', 'grass_generator', 2),
        ('Minions · INTERMEDIATE', 'leafair', 2),
        ('Minions · INTERMEDIATE', 'lightning_drop', 1),
        ('Minions · INTERMEDIATE', 'life_tree', 2),
        ('Minions · INTERMEDIATE', 'seed_nest', 3),
        ('Minions · INTERMEDIATE', 'zap_mouse', 3),
        ('Minions · INTERMEDIATE', 'grass_generator', 2),
        ('Minions · INTERMEDIATE', 'thunder_bird_swarm', 2),
        ('Minions · ADVANCED', 'leafair', 2),
        ('Minions · ADVANCED', 'seed_nest', 2),
        ('Minions · ADVANCED', 'zap_mouse', 3),
        ('Minions · ADVANCED', 'grass_generator', 2),
        ('Minions · ADVANCED', 'thunder_bird_swarm', 2),
        ('Minions · ADVANCED', 'vine_colony', 2),
        ('Minions · ADVANCED', 'vine_spirit', 2),
        ('Minions · ELITE', 'leafair', 2),
        ('Minions · ELITE', 'seed_nest', 2),
        ('Minions · ELITE', 'zap_mouse', 3),
        ('Minions · ELITE', 'mana_well', 1),
        ('Minions · ELITE', 'thunder_bird_swarm', 2),
        ('Minions · ELITE', 'vine_colony', 2),
        ('Minions · ELITE', 'vine_spirit', 2),
        ('Minions · ELITE', 'storm_stag', 1),
    -- Grass
        ('Grass · INTRO', 'leafair', 3),
        ('Grass · INTRO', 'razor_gale', 3),
        ('Grass · INTRO', 'life_tree', 3),
        ('Grass · INTRO', 'seed_nest', 3),
        ('Grass · INTRO', 'wind_spirit', 3),
        ('Grass · BEGINNER', 'leafair', 3),
        ('Grass · BEGINNER', 'life_tree', 2),
        ('Grass · BEGINNER', 'seed_nest', 3),
        ('Grass · BEGINNER', 'wind_spirit', 3),
        ('Grass · BEGINNER', 'overgrowth', 2),
        ('Grass · BEGINNER', 'grass_generator', 2),
        ('Grass · INTERMEDIATE', 'leafair', 2),
        ('Grass · INTERMEDIATE', 'seed_nest', 3),
        ('Grass · INTERMEDIATE', 'wind_spirit', 2),
        ('Grass · INTERMEDIATE', 'overgrowth', 2),
        ('Grass · INTERMEDIATE', 'grass_generator', 2),
        ('Grass · INTERMEDIATE', 'healing_totem', 2),
        ('Grass · INTERMEDIATE', 'tree_golem', 2),
        ('Grass · ADVANCED', 'leafair', 1),
        ('Grass · ADVANCED', 'seed_nest', 2),
        ('Grass · ADVANCED', 'wind_spirit', 2),
        ('Grass · ADVANCED', 'overgrowth', 2),
        ('Grass · ADVANCED', 'grass_generator', 2),
        ('Grass · ADVANCED', 'tree_golem', 2),
        ('Grass · ADVANCED', 'vine_colony', 2),
        ('Grass · ADVANCED', 'vine_spirit', 2),
        ('Grass · ELITE', 'seed_nest', 2),
        ('Grass · ELITE', 'wind_spirit', 1),
        ('Grass · ELITE', 'overgrowth', 2),
        ('Grass · ELITE', 'grass_generator', 2),
        ('Grass · ELITE', 'tree_golem', 2),
        ('Grass · ELITE', 'vine_colony', 2),
        ('Grass · ELITE', 'vine_spirit', 2),
        ('Grass · ELITE', 'evil_ent', 2),
    -- Shock
        ('Shock · INTRO', 'chain_lightning', 2),
        ('Shock · INTRO', 'water_explosion', 3),
        ('Shock · INTRO', 'bubble_generator', 2),
        ('Shock · INTRO', 'electric_tower', 3),
        ('Shock · INTRO', 'water_slime_swarm', 3),
        ('Shock · INTRO', 'zap_mouse', 2),
        ('Shock · BEGINNER', 'chain_lightning', 2),
        ('Shock · BEGINNER', 'tide_call', 1),
        ('Shock · BEGINNER', 'bubble_generator', 2),
        ('Shock · BEGINNER', 'electric_tower', 3),
        ('Shock · BEGINNER', 'water_slime_swarm', 3),
        ('Shock · BEGINNER', 'zap_mouse', 2),
        ('Shock · BEGINNER', 'shock_overload', 2),
        ('Shock · INTERMEDIATE', 'chain_lightning', 2),
        ('Shock · INTERMEDIATE', 'tide_call', 1),
        ('Shock · INTERMEDIATE', 'electric_tower', 3),
        ('Shock · INTERMEDIATE', 'water_slime_swarm', 2),
        ('Shock · INTERMEDIATE', 'zap_mouse', 2),
        ('Shock · INTERMEDIATE', 'shock_overload', 2),
        ('Shock · INTERMEDIATE', 'shock_trap', 1),
        ('Shock · INTERMEDIATE', 'storm_rider', 2),
        ('Shock · ADVANCED', 'chain_lightning', 2),
        ('Shock · ADVANCED', 'electric_tower', 2),
        ('Shock · ADVANCED', 'water_slime_swarm', 2),
        ('Shock · ADVANCED', 'zap_mouse', 2),
        ('Shock · ADVANCED', 'shock_overload', 2),
        ('Shock · ADVANCED', 'tidal_warhead', 1),
        ('Shock · ADVANCED', 'shock_trap', 2),
        ('Shock · ADVANCED', 'storm_rider', 2),
        ('Shock · ELITE', 'chain_lightning', 2),
        ('Shock · ELITE', 'electric_tower', 2),
        ('Shock · ELITE', 'zap_mouse', 2),
        ('Shock · ELITE', 'shock_overload', 1),
        ('Shock · ELITE', 'tidal_warhead', 2),
        ('Shock · ELITE', 'shock_trap', 2),
        ('Shock · ELITE', 'storm_rider', 2),
        ('Shock · ELITE', 'cloud_dragon', 2),
    -- Water Bomb
        ('Water Bomb · INTRO', 'tide_call', 3),
        ('Water Bomb · INTRO', 'water_explosion', 3),
        ('Water Bomb · INTRO', 'bubble_generator', 3),
        ('Water Bomb · INTRO', 'water_slime_swarm', 3),
        ('Water Bomb · INTRO', 'wind_spirit', 3),
        ('Water Bomb · BEGINNER', 'razor_gale', 1),
        ('Water Bomb · BEGINNER', 'water_explosion', 3),
        ('Water Bomb · BEGINNER', 'bubble_generator', 2),
        ('Water Bomb · BEGINNER', 'water_slime_swarm', 3),
        ('Water Bomb · BEGINNER', 'wind_spirit', 2),
        ('Water Bomb · BEGINNER', 'wind_totem', 2),
        ('Water Bomb · BEGINNER', 'tidal_warhead', 2),
        ('Water Bomb · INTERMEDIATE', 'razor_gale', 2),
        ('Water Bomb · INTERMEDIATE', 'water_explosion', 2),
        ('Water Bomb · INTERMEDIATE', 'bubble_generator', 2),
        ('Water Bomb · INTERMEDIATE', 'water_slime_swarm', 3),
        ('Water Bomb · INTERMEDIATE', 'wind_spirit', 2),
        ('Water Bomb · INTERMEDIATE', 'tidal_warhead', 2),
        ('Water Bomb · INTERMEDIATE', 'bubble_spirit', 2),
        ('Water Bomb · ADVANCED', 'razor_gale', 1),
        ('Water Bomb · ADVANCED', 'water_explosion', 2),
        ('Water Bomb · ADVANCED', 'bubble_generator', 2),
        ('Water Bomb · ADVANCED', 'water_slime_swarm', 2),
        ('Water Bomb · ADVANCED', 'tidal_warhead', 2),
        ('Water Bomb · ADVANCED', 'bubble_spirit', 2),
        ('Water Bomb · ADVANCED', 'aqua_archer', 2),
        ('Water Bomb · ADVANCED', 'bomb_sprite', 2),
        ('Water Bomb · ELITE', 'razor_gale', 1),
        ('Water Bomb · ELITE', 'water_explosion', 2),
        ('Water Bomb · ELITE', 'water_slime_swarm', 2),
        ('Water Bomb · ELITE', 'tidal_warhead', 2),
        ('Water Bomb · ELITE', 'bubble_spirit', 2),
        ('Water Bomb · ELITE', 'aqua_archer', 2),
        ('Water Bomb · ELITE', 'bomb_sprite', 2),
        ('Water Bomb · ELITE', 'sea_serpent', 2),
    -- Summoner
        ('Summoner · INTRO', 'leafair', 3),
        ('Summoner · INTRO', 'lightning_drop', 3),
        ('Summoner · INTRO', 'electric_tower', 3),
        ('Summoner · INTRO', 'life_tree', 3),
        ('Summoner · INTRO', 'seed_nest', 3),
        ('Summoner · BEGINNER', 'leafair', 3),
        ('Summoner · BEGINNER', 'lightning_drop', 3),
        ('Summoner · BEGINNER', 'electric_tower', 2),
        ('Summoner · BEGINNER', 'life_tree', 2),
        ('Summoner · BEGINNER', 'seed_nest', 3),
        ('Summoner · BEGINNER', 'thunder_spirit', 2),
        ('Summoner · INTERMEDIATE', 'leafair', 1),
        ('Summoner · INTERMEDIATE', 'lightning_drop', 2),
        ('Summoner · INTERMEDIATE', 'electric_tower', 2),
        ('Summoner · INTERMEDIATE', 'seed_nest', 2),
        ('Summoner · INTERMEDIATE', 'mana_well', 2),
        ('Summoner · INTERMEDIATE', 'thunder_spirit', 2),
        ('Summoner · INTERMEDIATE', 'tree_golem', 2),
        ('Summoner · INTERMEDIATE', 'vine_colony', 2),
        ('Summoner · ADVANCED', 'lightning_drop', 2),
        ('Summoner · ADVANCED', 'seed_nest', 3),
        ('Summoner · ADVANCED', 'mana_well', 2),
        ('Summoner · ADVANCED', 'thunder_spirit', 2),
        ('Summoner · ADVANCED', 'tree_golem', 2),
        ('Summoner · ADVANCED', 'vine_colony', 2),
        ('Summoner · ADVANCED', 'dimension_toad', 2),
        ('Summoner · ELITE', 'lightning_drop', 2),
        ('Summoner · ELITE', 'seed_nest', 3),
        ('Summoner · ELITE', 'mana_well', 2),
        ('Summoner · ELITE', 'tree_golem', 2),
        ('Summoner · ELITE', 'vine_colony', 2),
        ('Summoner · ELITE', 'dimension_toad', 2),
        ('Summoner · ELITE', 'cloud_dragon', 1),
        ('Summoner · ELITE', 'storm_stag', 1),
    -- Golems
        ('Golems · INTRO', 'rock_drop', 3),
        ('Golems · INTRO', 'sand_storm', 3),
        ('Golems · INTRO', 'ember_spirit_swarm', 3),
        ('Golems · INTRO', 'mini_rock_swarm', 3),
        ('Golems · INTRO', 'rock_turret', 3),
        ('Golems · BEGINNER', 'rock_drop', 3),
        ('Golems · BEGINNER', 'sand_storm', 2),
        ('Golems · BEGINNER', 'ember_spirit_swarm', 2),
        ('Golems · BEGINNER', 'mini_rock_swarm', 3),
        ('Golems · BEGINNER', 'rock_turret', 3),
        ('Golems · BEGINNER', 'towerback', 2),
        ('Golems · INTERMEDIATE', 'rock_drop', 2),
        ('Golems · INTERMEDIATE', 'mini_rock_swarm', 3),
        ('Golems · INTERMEDIATE', 'rock_turret', 2),
        ('Golems · INTERMEDIATE', 'boulder_strike', 2),
        ('Golems · INTERMEDIATE', 'titan_remnant', 2),
        ('Golems · INTERMEDIATE', 'towerback', 2),
        ('Golems · INTERMEDIATE', 'rock_golem', 2),
        ('Golems · ADVANCED', 'rock_drop', 2),
        ('Golems · ADVANCED', 'mini_rock_swarm', 2),
        ('Golems · ADVANCED', 'boulder_strike', 1),
        ('Golems · ADVANCED', 'titan_remnant', 2),
        ('Golems · ADVANCED', 'towerback', 2),
        ('Golems · ADVANCED', 'rock_golem', 2),
        ('Golems · ADVANCED', 'rock_mage', 2),
        ('Golems · ADVANCED', 'wall_golem', 2),
        ('Golems · ELITE', 'rock_drop', 1),
        ('Golems · ELITE', 'mini_rock_swarm', 2),
        ('Golems · ELITE', 'crater', 2),
        ('Golems · ELITE', 'titan_remnant', 2),
        ('Golems · ELITE', 'rock_golem', 2),
        ('Golems · ELITE', 'rock_mage', 2),
        ('Golems · ELITE', 'wall_golem', 2),
        ('Golems · ELITE', 'magma_spirit', 2),
    -- Hospitality
        ('Warm Welcome', 'ember_spirit_swarm', 3),
        ('Warm Welcome', 'mini_rock_swarm', 3),
        ('Warm Welcome', 'seed_nest', 3),
        ('Warm Welcome', 'water_slime_swarm', 3),
        ('Warm Welcome', 'zap_mouse', 3)
;

-- 이름만으로 덱을 고르지 않는다. '봇의 기본 덱' 처럼 이름이 겹치는 덱이 있고, 이 파일이
-- 건드리는 것은 봇이 가진 덱뿐이다.
CREATE TEMP TABLE bot_deck_target (
    deck_id BIGINT PRIMARY KEY,
    deck_name VARCHAR(31) NOT NULL,
    user_id BIGINT NOT NULL
) ON COMMIT DROP;

INSERT INTO bot_deck_target(deck_id, deck_name, user_id)
SELECT deck.id, deck.name, deck.user_id
FROM decks deck
JOIN bot_personas persona ON persona.user_id = deck.user_id
WHERE deck.name IN (SELECT deck_name FROM bot_deck_seed);

DELETE FROM deck_cards
WHERE deck_id IN (SELECT deck_id FROM bot_deck_target);

INSERT INTO deck_cards(deck_id, magic_id, count)
SELECT target.deck_id, magic.id, seed.copies
FROM bot_deck_seed seed
JOIN bot_deck_target target ON target.deck_name = seed.deck_name
JOIN magics magic ON magic.name = seed.magic_name;

-- 소유를 덱에 맞춘다. 게임 서버는 deck_cards 만 읽고 소유를 보지 않지만, 로비의 DeckValidator
-- 는 사람이 덱을 저장할 때 user_magics 를 본다. 봇만 예외로 두면 admin 에서 봇 덱을 열었을 때
-- 저장할 수 없는 덱으로 보인다.
DELETE FROM user_magics
WHERE user_id IN (SELECT user_id FROM bot_deck_target);

INSERT INTO user_magics(user_id, magic_id, count)
SELECT target.user_id, magic.id, 3
FROM bot_deck_seed seed
JOIN bot_deck_target target ON target.deck_name = seed.deck_name
JOIN magics magic ON magic.name = seed.magic_name;

DO $$
DECLARE
    failure TEXT;
BEGIN
    IF (SELECT COUNT(*) FROM bot_deck_target) <> 46 THEN
        RAISE EXCEPTION 'Expected 46 bot decks, matched %', (SELECT COUNT(*) FROM bot_deck_target);
    END IF;

    -- 1, 2, 3, 4번 규칙. 접대 봇은 4번의 예외이자 더 센 규칙(15장 전부 소환)을 받는다.
    SELECT string_agg(problem, '; ')
    INTO failure
    FROM (
        SELECT target.deck_name
               || ': ' || SUM(deck_card.count) || ' cards'
               || ', ' || MAX(deck_card.count) || ' max copies'
               || ', ' || SUM(deck_card.count) FILTER (
                      WHERE magic.cast_kind IN ('Summon', 'Spawn')) || ' bodies'
               || ', ' || COUNT(*) FILTER (WHERE magic.purpose <> 'PLAYER') || ' non-player'
               || ', ' || COUNT(*) FILTER (WHERE mana.value IS NULL) || ' unpriced' AS problem
        FROM bot_deck_target target
        JOIN deck_cards deck_card ON deck_card.deck_id = target.deck_id
        JOIN magics magic ON magic.id = deck_card.magic_id
        LEFT JOIN LATERAL (
            SELECT parameter_value.value
            FROM parameter_values parameter_value
            JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
            JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
            WHERE game_object.name = magic.name AND parameter.name = 'mana_cost'
        ) mana ON TRUE
        GROUP BY target.deck_name
        HAVING SUM(deck_card.count) <> 15
            OR MAX(deck_card.count) > 3
            OR COUNT(*) FILTER (WHERE magic.purpose <> 'PLAYER') > 0
            OR COUNT(*) FILTER (WHERE mana.value IS NULL) > 0
            OR SUM(deck_card.count) FILTER (WHERE magic.cast_kind IN ('Summon', 'Spawn'))
               < CASE WHEN target.deck_name = 'Warm Welcome' THEN 15 ELSE 8 END
    ) invalid_decks;

    IF failure IS NOT NULL THEN
        RAISE EXCEPTION 'Bot deck construction rules broken -- %', failure;
    END IF;

    -- 5번 규칙. 계열 안에서 tier 가 오르는데 장당 평균 mana 가 그대로거나 내려가면, 위 tier 가
    -- 아래 tier 보다 무엇을 더 쥐고 있는지 설명할 수 없다.
    SELECT string_agg(concept || ' ' || tier || ' ' || average_mana, '; ' ORDER BY concept, tier_order)
    INTO failure
    FROM (
        SELECT concept, tier, tier_order, average_mana,
               lag(average_mana) OVER (PARTITION BY concept ORDER BY tier_order) AS lower_tier_mana
        FROM (
            SELECT split_part(target.deck_name, ' · ', 1) AS concept,
                   split_part(target.deck_name, ' · ', 2) AS tier,
                   array_position(
                       ARRAY['INTRO', 'BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'ELITE'],
                       split_part(target.deck_name, ' · ', 2)) AS tier_order,
                   ROUND((SUM(mana.value * deck_card.count) / SUM(deck_card.count))::NUMERIC, 1) AS average_mana
            FROM bot_deck_target target
            JOIN deck_cards deck_card ON deck_card.deck_id = target.deck_id
            JOIN magics magic ON magic.id = deck_card.magic_id
            JOIN LATERAL (
                SELECT parameter_value.value
                FROM parameter_values parameter_value
                JOIN parameters parameter ON parameter.id = parameter_value.parameter_id
                JOIN game_objects game_object ON game_object.id = parameter_value.game_object_id
                WHERE game_object.name = magic.name AND parameter.name = 'mana_cost'
            ) mana ON TRUE
            WHERE target.deck_name <> 'Warm Welcome'
            GROUP BY target.deck_name
        ) deck_curve
    ) tier_steps
    WHERE lower_tier_mana IS NOT NULL AND average_mana <= lower_tier_mana;

    IF failure IS NOT NULL THEN
        RAISE EXCEPTION 'Average mana does not rise with tier -- %', failure;
    END IF;

    -- 6번 규칙.
    SELECT string_agg(target.deck_name || ': ' || magic.name, '; ')
    INTO failure
    FROM bot_deck_target target
    JOIN deck_cards deck_card ON deck_card.deck_id = target.deck_id
    JOIN magics magic ON magic.id = deck_card.magic_id
    LEFT JOIN user_magics owned
           ON owned.user_id = target.user_id AND owned.magic_id = deck_card.magic_id
    WHERE owned.count IS NULL OR owned.count < deck_card.count;

    IF failure IS NOT NULL THEN
        RAISE EXCEPTION 'Bot does not own a card its deck holds -- %', failure;
    END IF;
END
$$;

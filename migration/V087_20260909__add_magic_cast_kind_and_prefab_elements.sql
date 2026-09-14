-- magic-card: 어느 계열이고 어느 prefab 을 쓰는지를 magics 가 들고, 원소는 prefab 이 든다.
--
-- 마법 구현 클래스 72개 중 63개는 생성자에서 super(...) 한 줄만 한다. 담고 있는 정보가
-- "어느 계열인가"와 "어느 prefab 인가" 둘뿐이라, 그 둘을 행으로 옮기면 클래스가 사라지고
-- 마법 추가가 배포가 아니라 행 추가가 된다. 코드가 있는 9개는 cast_kind = 'Code' 로 남아
-- 지금처럼 magics.name 으로 bean 을 찾는다.
--
-- prefab 이름은 PrefabType 의 bean 이름에서 _prefab 을 뗀 것이고, 그것이 곧
-- game_objects.name 이다. PrefabType 102개 전부 이 규칙을 따르는 것을 확인했다.
--
-- 원소는 마법이 아니라 prefab 에 붙인다. 전투에서 배율을 정하는 것이 GameObject 의 원소
-- 집합이고, 마법마다 따로 적어 두면 prefab 을 바꿀 때 같이 고쳐야 하는 값이 하나 더 생긴다.
-- 값은 게임 서버의 setElement 호출에서 뽑았다. 원소를 갖지 않는 prefab 은 행을 만들지 않는다.

ALTER TABLE magics
    ADD COLUMN IF NOT EXISTS cast_kind VARCHAR(16),
    ADD COLUMN IF NOT EXISTS prefab    VARCHAR(63);

-- ---------------------------------------------------------------- 계열과 prefab
UPDATE magics SET cast_kind = 'Spawn', prefab = 'aqua_archer' WHERE name = 'aqua_archer';
UPDATE magics SET cast_kind = 'Summon', prefab = 'bubble_generator' WHERE name = 'bubble_generator';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'bubble_spirit' WHERE name = 'bubble_spirit';
UPDATE magics SET cast_kind = 'Code', prefab = 'ground_cannon' WHERE name = 'cannon';
UPDATE magics SET cast_kind = 'Shot', prefab = 'chain_lightning' WHERE name = 'chain_lightning';
UPDATE magics SET cast_kind = 'Code', prefab = NULL WHERE name = 'chicken_commando';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'cloud_dragon' WHERE name = 'cloud_dragon';
UPDATE magics SET cast_kind = 'Summon', prefab = 'crater' WHERE name = 'crater';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'dimension_toad' WHERE name = 'dimension_toad';
UPDATE magics SET cast_kind = 'Summon', prefab = 'electric_tower' WHERE name = 'electric_tower';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'fire_slime' WHERE name = 'ember_spirit_swarm';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'evil_ent' WHERE name = 'evil_ent';
UPDATE magics SET cast_kind = 'Drop', prefab = 'fire_drop' WHERE name = 'fire_drop';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'fire_lord_spirit' WHERE name = 'fire_lord_spirit';
UPDATE magics SET cast_kind = 'Shot', prefab = 'fire_shot' WHERE name = 'fire_shot';
UPDATE magics SET cast_kind = 'Summon', prefab = 'fire_summon' WHERE name = 'fire_slime_nest';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'fire_spirit' WHERE name = 'fire_spirit';
UPDATE magics SET cast_kind = 'Drop', prefab = 'frenzy_totem' WHERE name = 'frenzy_totem';
UPDATE magics SET cast_kind = 'Summon', prefab = 'healing_totem' WHERE name = 'healing_totem';
UPDATE magics SET cast_kind = 'Drop', prefab = 'leafair' WHERE name = 'leafair';
UPDATE magics SET cast_kind = 'Summon', prefab = 'life_tree' WHERE name = 'life_tree';
UPDATE magics SET cast_kind = 'Drop', prefab = 'lightning_cloud' WHERE name = 'lightning_drop';
UPDATE magics SET cast_kind = 'Explosion', prefab = 'electric_explode' WHERE name = 'lightning_explosion';
UPDATE magics SET cast_kind = 'Shot', prefab = 'electric_shot' WHERE name = 'lightning_shot';
UPDATE magics SET cast_kind = 'Summon', prefab = 'electric_summon' WHERE name = 'lightning_slime_nest';
UPDATE magics SET cast_kind = 'Explosion', prefab = 'magma_explosion' WHERE name = 'magma_explosion';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'magma_spirit' WHERE name = 'magma_spirit';
UPDATE magics SET cast_kind = 'Summon', prefab = 'mana_well' WHERE name = 'mana_well';
UPDATE magics SET cast_kind = 'Drop', prefab = 'meteor_shower' WHERE name = 'meteor_shower';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'mini_rock' WHERE name = 'mini_rock_swarm';
UPDATE magics SET cast_kind = 'Drop', prefab = 'nature_drop' WHERE name = 'nature_drop';
UPDATE magics SET cast_kind = 'Summon', prefab = 'pve_nature_slime_nest' WHERE name = 'nature_slime_nest';
UPDATE magics SET cast_kind = 'Explosion', prefab = 'overgrowth' WHERE name = 'overgrowth';
UPDATE magics SET cast_kind = 'Summon', prefab = 'pve_water_slime_nest' WHERE name = 'pve_water_slime_nest';
UPDATE magics SET cast_kind = 'Summon', prefab = 'rallying_totem' WHERE name = 'rallying_totem';
UPDATE magics SET cast_kind = 'Explosion', prefab = 'razor_gale' WHERE name = 'razor_gale';
UPDATE magics SET cast_kind = 'Drop', prefab = 'rock_drop' WHERE name = 'rock_drop';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'rock_golem' WHERE name = 'rock_golem';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'rock_mage' WHERE name = 'rock_mage';
UPDATE magics SET cast_kind = 'Shot', prefab = 'rock_rolling' WHERE name = 'rock_rolling';
UPDATE magics SET cast_kind = 'Summon', prefab = 'rock_summon' WHERE name = 'rock_slime_nest';
UPDATE magics SET cast_kind = 'Summon', prefab = 'rock_turret' WHERE name = 'rock_turret';
UPDATE magics SET cast_kind = 'Explosion', prefab = 'sand_storm' WHERE name = 'sand_storm';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'sea_serpent' WHERE name = 'sea_serpent';
UPDATE magics SET cast_kind = 'Summon', prefab = 'seed_nest' WHERE name = 'seed_nest';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'seed_spirit' WHERE name = 'seed_spirit_swarm';
UPDATE magics SET cast_kind = 'Explosion', prefab = 'shock_overload' WHERE name = 'shock_overload';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'storm_rider' WHERE name = 'storm_rider';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'storm_stag' WHERE name = 'storm_stag';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'thunder_bird' WHERE name = 'thunder_bird_swarm';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'thunder_spirit' WHERE name = 'thunder_spirit';
UPDATE magics SET cast_kind = 'Shot', prefab = 'tide_call' WHERE name = 'tide_call';
UPDATE magics SET cast_kind = 'Explosion', prefab = 'tornado_strike' WHERE name = 'tornado_strike';
UPDATE magics SET cast_kind = 'Code', prefab = 'ground_tower' WHERE name = 'tower';
UPDATE magics SET cast_kind = 'Summon', prefab = 'towerback' WHERE name = 'towerback';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'tree_golem' WHERE name = 'tree_golem';
UPDATE magics SET cast_kind = 'Summon', prefab = 'vine_colony' WHERE name = 'vine_colony';
UPDATE magics SET cast_kind = 'Code', prefab = NULL WHERE name = 'vine_fan';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'vine_spirit' WHERE name = 'vine_spirit';
UPDATE magics SET cast_kind = 'Code', prefab = NULL WHERE name = 'vine_toss';
UPDATE magics SET cast_kind = 'Code', prefab = NULL WHERE name = 'vine_world';
UPDATE magics SET cast_kind = 'Explosion', prefab = 'water_explosion' WHERE name = 'water_explosion';
UPDATE magics SET cast_kind = 'Shot', prefab = 'water_shot' WHERE name = 'water_shot';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'water_slime' WHERE name = 'water_slime_swarm';
UPDATE magics SET cast_kind = 'Code', prefab = NULL WHERE name = 'will_o_wisp';
UPDATE magics SET cast_kind = 'Code', prefab = 'wind_blade' WHERE name = 'wind_blade';
UPDATE magics SET cast_kind = 'Drop', prefab = 'wind_drop' WHERE name = 'wind_drop';
UPDATE magics SET cast_kind = 'Code', prefab = 'wind_explode' WHERE name = 'wind_explosion';
UPDATE magics SET cast_kind = 'Summon', prefab = 'wind_summon' WHERE name = 'wind_slime_nest';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'wind_spirit' WHERE name = 'wind_spirit';
UPDATE magics SET cast_kind = 'Summon', prefab = 'wind_totem' WHERE name = 'wind_totem';
UPDATE magics SET cast_kind = 'Spawn', prefab = 'zap_mouse' WHERE name = 'zap_mouse';

-- 위 목록에 없는 magics 행은 게임 서버에 구현 클래스가 없는 것들이다. 조합도 없어서 개편
-- 전에도 시전할 수 없었고, 지금 게임 서버는 기동할 때마다 이들에 대해
-- "[Magic:Loading] magic (...) bean is not available" 경고를 찍고 넘어간다.
--
-- 지우지 않는다. user_magics 가 사용자마다 이 행들을 참조하고 있어서 삭제는 콘텐츠 결정이고
-- WordOnlineDatabase #126 이 다룬다. 여기서는 지금 동작과 같은 자리인 'Code' 로 두어서
-- 게임 서버가 하던 대로 bean 을 찾다 없으면 건너뛰게 한다. 어떤 행이 그런지는 NOTICE 로 남긴다.
DO
$BODY$
    DECLARE unknown_magics TEXT;
    BEGIN
        SELECT string_agg(name, ', ' ORDER BY name) INTO unknown_magics
        FROM magics WHERE cast_kind IS NULL;
        IF unknown_magics IS NOT NULL THEN
            RAISE NOTICE '게임 서버에 구현이 없어 Code 로 둔 magics: %', unknown_magics;
        END IF;
    END
$BODY$;

UPDATE magics SET cast_kind = 'Code' WHERE cast_kind IS NULL;

ALTER TABLE magics ALTER COLUMN cast_kind SET NOT NULL;

ALTER TABLE magics DROP CONSTRAINT IF EXISTS chk_magics_cast_kind;
ALTER TABLE magics ADD CONSTRAINT chk_magics_cast_kind
    CHECK (cast_kind IN ('Shot', 'Drop', 'Explosion', 'Summon', 'Spawn', 'Code'));

-- Code 가 아니면 게임 서버가 prefab 없이는 마법을 만들 수 없다.
ALTER TABLE magics DROP CONSTRAINT IF EXISTS chk_magics_prefab_required;
ALTER TABLE magics ADD CONSTRAINT chk_magics_prefab_required
    CHECK (cast_kind = 'Code' OR prefab IS NOT NULL);

-- --------------------------------------------------------------------- prefab 원소
CREATE TABLE IF NOT EXISTS prefab_elements (
    prefab  VARCHAR(63) NOT NULL,
    element VARCHAR(10) NOT NULL,
    CONSTRAINT pk_prefab_elements PRIMARY KEY (prefab, element),
    CONSTRAINT chk_prefab_elements_element
        CHECK (element IN ('Fire', 'Water', 'Lightning', 'Rock', 'Nature', 'Wind'))
);

INSERT INTO prefab_elements(prefab, element)
VALUES ('aqua_archer', 'Water'),
       ('bubble_generator', 'Water'),
       ('bubble_spirit', 'Water'),
       ('bubble_spirit', 'Wind'),
       ('chain_lightning', 'Lightning'),
       ('chicken_commando', 'Wind'),
       ('cloud_dragon', 'Lightning'),
       ('cloud_dragon', 'Water'),
       ('cloud_dragon', 'Wind'),
       ('crater', 'Fire'),
       ('crater_ember', 'Fire'),
       ('dimension_toad', 'Fire'),
       ('dimension_toad', 'Lightning'),
       ('electric_explode', 'Lightning'),
       ('electric_field', 'Lightning'),
       ('electric_shot', 'Lightning'),
       ('electric_slime', 'Lightning'),
       ('electric_summon', 'Lightning'),
       ('electric_tower', 'Lightning'),
       ('evil_ent', 'Fire'),
       ('evil_ent', 'Nature'),
       ('fire_child_spirit', 'Fire'),
       ('fire_drop', 'Fire'),
       ('fire_explode', 'Fire'),
       ('fire_field', 'Fire'),
       ('fire_lord_spirit', 'Fire'),
       ('fire_lord_spirit', 'Wind'),
       ('fire_rune', 'Fire'),
       ('fire_shot', 'Fire'),
       ('fire_slime', 'Fire'),
       ('fire_spirit', 'Fire'),
       ('fire_spirit', 'Wind'),
       ('fire_summon', 'Fire'),
       ('fire_tadpole', 'Fire'),
       ('giant_vine', 'Nature'),
       ('ground_cannon', 'Rock'),
       ('ground_tower', 'Rock'),
       ('healing_totem', 'Nature'),
       ('healing_totem', 'Water'),
       ('leaf_explode', 'Nature'),
       ('leaf_field', 'Nature'),
       ('leaf_slime', 'Nature'),
       ('leafair', 'Nature'),
       ('life_tree', 'Nature'),
       ('lightning_cloud', 'Lightning'),
       ('lightning_rune', 'Lightning'),
       ('lightning_tadpole', 'Lightning'),
       ('magma_explosion', 'Fire'),
       ('magma_fist', 'Fire'),
       ('magma_fist', 'Rock'),
       ('magma_spirit', 'Fire'),
       ('magma_spirit', 'Rock'),
       ('mana_well', 'Lightning'),
       ('mana_well', 'Nature'),
       ('meteor_drop', 'Fire'),
       ('meteor_drop', 'Rock'),
       ('meteor_shower', 'Fire'),
       ('meteor_shower', 'Rock'),
       ('mini_rock', 'Rock'),
       ('nature_drop', 'Nature'),
       ('nature_rune', 'Nature'),
       ('overgrowth', 'Nature'),
       ('pve_nature_slime_nest', 'Nature'),
       ('pve_vine_colony', 'Nature'),
       ('pve_vine_witch', 'Nature'),
       ('pve_water_slime_nest', 'Water'),
       ('rallying_totem', 'Fire'),
       ('razor_gale', 'Wind'),
       ('rock_drop', 'Rock'),
       ('rock_explode', 'Rock'),
       ('rock_golem', 'Rock'),
       ('rock_mage', 'Rock'),
       ('rock_remnant', 'Rock'),
       ('rock_rolling', 'Rock'),
       ('rock_rune', 'Rock'),
       ('rock_slime', 'Rock'),
       ('rock_summon', 'Rock'),
       ('rock_turret', 'Rock'),
       ('sand_storm', 'Rock'),
       ('sand_storm', 'Wind'),
       ('sea_serpent', 'Water'),
       ('seed_nest', 'Nature'),
       ('seed_spirit', 'Nature'),
       ('shock_overload', 'Lightning'),
       ('storm_rider', 'Lightning'),
       ('storm_rider', 'Water'),
       ('storm_stag', 'Lightning'),
       ('thunder_bird', 'Lightning'),
       ('thunder_spirit', 'Lightning'),
       ('thunder_spirit', 'Wind'),
       ('tide_call', 'Water'),
       ('tornado_strike', 'Nature'),
       ('tornado_strike', 'Wind'),
       ('towerback', 'Rock'),
       ('tree_golem', 'Nature'),
       ('vine', 'Nature'),
       ('vine_colony', 'Nature'),
       ('vine_spirit', 'Nature'),
       ('vine_toss', 'Nature'),
       ('water_explode', 'Water'),
       ('water_explosion', 'Water'),
       ('water_field', 'Water'),
       ('water_rune', 'Water'),
       ('water_shot', 'Water'),
       ('water_slime', 'Water'),
       ('wind_blade', 'Wind'),
       ('wind_drop', 'Wind'),
       ('wind_explode', 'Wind'),
       ('wind_rune', 'Wind'),
       ('wind_slime', 'Wind'),
       ('wind_spirit', 'Wind'),
       ('wind_summon', 'Wind'),
       ('wind_totem', 'Wind'),
       ('zap_mouse', 'Lightning')
ON CONFLICT (prefab, element) DO NOTHING;

-- magics.element 는 만들지 않는다. 마법의 원소는 magics.prefab 으로 join 해서 얻는다.

-- no-tags: 등록된 마법의 시작·레벨 보상 배치만 변경하며 새 마법이나 오브젝트는 추가하지 않는다.
-- 같은 마법을 시작과 후속 레벨에서 지급할 수 있다. 상자 후보 조회는 magic_id별로 중복을 제거한다.
ALTER TABLE progression_magic_rewards
    DROP CONSTRAINT IF EXISTS progression_magic_rewards_pkey,
    DROP CONSTRAINT IF EXISTS progression_magic_rewards_faction_magic_id_key;
ALTER TABLE progression_magic_rewards
    ADD PRIMARY KEY (faction, unlock_level, magic_id);

-- 이미 받은 카드·덱·미수령 원장은 보존하고 앞으로 조회·지급할 정책만 교체한다.
DELETE FROM progression_magic_rewards WHERE faction IN ('HELL', 'NATURE');

DO $$
DECLARE reward record; magic_row_id bigint;
BEGIN
    FOR reward IN SELECT * FROM (VALUES
        ('fire_shot','HELL',1), ('rock_golem','HELL',1),
        ('rock_mage','HELL',1), ('wall_golem','HELL',1), ('stone_gargoyle','HELL',1),
        ('chain_lightning','NATURE',1), ('electric_spearman','NATURE',1),
        ('aqua_archer','NATURE',1), ('tree_golem','NATURE',1), ('thunder_spirit','NATURE',1),
        ('ember_spirit_swarm','HELL',5), ('water_slime_swarm','NATURE',5),
        ('meteor_shower','HELL',10), ('tornado_strike','NATURE',10),
        ('rock_golem','HELL',15), ('life_tree','NATURE',15),
        ('magma_spirit','HELL',20), ('vine_spirit','NATURE',20),
        ('frenzy_totem','HELL',25), ('grass_generator','NATURE',25),
        ('dragon_tower','HELL',30), ('tide_call','NATURE',30),
        ('earth_call','HELL',35), ('overgrowth','NATURE',35),
        ('crater_carrier','HELL',40), ('storm_rider','NATURE',40),
        ('evil_ent','HELL',45), ('vine_world','NATURE',45),
        ('fire_lord_spirit','HELL',50), ('sea_serpent','NATURE',50)
    ) AS r(name, faction, unlock_level)
    LOOP
        SELECT id INTO STRICT magic_row_id FROM magics WHERE name = reward.name AND purpose = 'PLAYER';
        INSERT INTO progression_magic_rewards(magic_id, faction, unlock_level)
        VALUES (magic_row_id, reward.faction, reward.unlock_level);
    END LOOP;
END $$;

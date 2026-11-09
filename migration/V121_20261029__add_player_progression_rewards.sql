-- no-tags: 성장 보상만 등록하며 마법과 게임 오브젝트는 추가하지 않는다.
CREATE TABLE player_progression (
    user_id bigint PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    faction varchar(16) CHECK (faction IN ('HELL', 'NATURE')),
    xp bigint NOT NULL DEFAULT 0 CHECK (xp >= 0),
    level int NOT NULL DEFAULT 1 CHECK (level BETWEEN 1 AND 50),
    currency bigint NOT NULL DEFAULT 0 CHECK (currency >= 0),
    created_at timestamptz NOT NULL DEFAULT now()
);

-- 친선전도 PVP로 저장되므로 매칭에서 시작한 경기만 별도로 표시한다.
CREATE TABLE progression_matches (
    session_id varchar(128) NOT NULL,
    user_id bigint NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (session_id, user_id)
);
CREATE TABLE progression_match_rewards (
    user_id bigint NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_record_id bigint NOT NULL REFERENCES statistic_game_sessions(id),
    xp int NOT NULL CHECK (xp >= 0),
    PRIMARY KEY (user_id, session_record_id)
);
CREATE INDEX idx_progression_matches_user ON progression_matches(user_id, session_id);

CREATE TABLE progression_magic_rewards (
    magic_id bigint PRIMARY KEY REFERENCES magics(id),
    faction varchar(16) NOT NULL CHECK (faction IN ('HELL', 'NATURE')),
    unlock_level int NOT NULL CHECK (unlock_level IN (1,5,10,15,20,25,30,35,40,45,50)),
    UNIQUE (faction, magic_id)
);
DO $$
DECLARE reward record; magic_row_id bigint;
BEGIN
    FOR reward IN SELECT * FROM (VALUES
        ('fire_shot','HELL',1), ('ember_spirit_swarm','HELL',1),
        ('towerback','HELL',1), ('rock_golem','HELL',1), ('magma_explosion','HELL',1),
        ('chain_lightning','NATURE',1), ('water_slime_swarm','NATURE',1),
        ('vine_spirit','NATURE',1), ('tree_golem','NATURE',1), ('water_explosion','NATURE',1),
        ('rock_mage','HELL',5), ('wind_spirit','NATURE',5),
        ('meteor_shower','HELL',10), ('tornado_strike','NATURE',10),
        ('mini_rock_swarm','HELL',15), ('life_tree','NATURE',15),
        ('magma_spirit','HELL',20), ('aqua_archer','NATURE',20),
        ('frenzy_totem','HELL',25), ('grass_generator','NATURE',25),
        ('dragon_tower','HELL',30), ('tide_call','NATURE',30),
        ('earth_call','HELL',35), ('overgrowth','NATURE',35),
        ('wall_golem','HELL',40), ('storm_rider','NATURE',40),
        ('evil_ent','HELL',45), ('vine_world','NATURE',45),
        ('fire_lord_spirit','HELL',50), ('sea_serpent','NATURE',50)
    ) AS r(name, faction, unlock_level)
    LOOP
        SELECT id INTO STRICT magic_row_id FROM magics WHERE name = reward.name AND purpose = 'PLAYER';
        INSERT INTO progression_magic_rewards(magic_id, faction, unlock_level)
        VALUES (magic_row_id, reward.faction, reward.unlock_level);
    END LOOP;
END $$;

ALTER TABLE user_chests ADD COLUMN reward_slots int NOT NULL DEFAULT 0 CHECK (reward_slots >= 0);
ALTER TABLE user_chests ADD COLUMN reward_source varchar(64);
CREATE UNIQUE INDEX idx_user_chests_reward_source ON user_chests(user_id, reward_source)
    WHERE reward_source IS NOT NULL;
INSERT INTO chests(key, sort_order) VALUES ('progression_chest', 2) ON CONFLICT (key) DO NOTHING;

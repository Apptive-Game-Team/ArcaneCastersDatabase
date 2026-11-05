-- no-tags: 성장 보상의 미수령 원장만 추가한다.
ALTER TABLE player_progression ADD COLUMN reward_baseline_level int NOT NULL DEFAULT 1
    CHECK (reward_baseline_level BETWEEN 1 AND 50);
-- 이미 자동 지급한 레벨 이하는 새 원장에서 다시 발급하지 않는다.
UPDATE player_progression SET reward_baseline_level = level;

CREATE TABLE progression_reward_claims (
    id bigserial PRIMARY KEY,
    user_id bigint NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    source varchar(64) NOT NULL,
    level int,
    created_at timestamptz NOT NULL DEFAULT now(),
    claimed_at timestamptz,
    UNIQUE (user_id, source),
    CHECK ((level IS NOT NULL AND level BETWEEN 2 AND 50 AND source = 'level:' || level::text)
        OR (level IS NULL AND source ~ '^daily:[0-9]{4}-[0-9]{2}-[0-9]{2}$'))
);
CREATE INDEX idx_progression_reward_claims_pending
    ON progression_reward_claims(user_id, id) WHERE claimed_at IS NULL;

CREATE TABLE progression_reward_items (
    claim_id bigint NOT NULL REFERENCES progression_reward_claims(id) ON DELETE CASCADE,
    position smallint NOT NULL CHECK (position >= 0),
    reward_type varchar(16) NOT NULL,
    magic_id bigint REFERENCES magics(id),
    chest_id bigint REFERENCES chests(id),
    reward_key varchar(128) NOT NULL,
    amount int NOT NULL CHECK (amount > 0),
    reward_slots int NOT NULL DEFAULT 0,
    granted_amount int CHECK (granted_amount >= 0 AND granted_amount <= amount),
    PRIMARY KEY (claim_id, position),
    CHECK ((reward_type = 'MAGIC' AND magic_id IS NOT NULL AND chest_id IS NULL AND reward_slots = 0)
        OR (reward_type = 'CHEST' AND magic_id IS NULL AND chest_id IS NOT NULL
            AND amount = 1 AND reward_slots BETWEEN 1 AND 7))
);

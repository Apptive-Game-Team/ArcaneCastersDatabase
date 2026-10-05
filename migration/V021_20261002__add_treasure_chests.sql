-- 모험을 클리어하면 받는 보물상자를 기록하기 위해 chests, chest_rewards, user_chests 를 추가한다.
-- 상자는 사용자 inventory 에 열리지 않은 채로 쌓이고, 나중에 한 화면에서 열면 그 상자의
-- 내용물 여러 개를 한꺼번에 받는다.
--   chests          상자 종류 catalog. key 는 application 이 쓰는 이름이다.
--   chest_rewards   상자 하나를 열 때 주는 보상 행. 상자당 여러 행을 둘 수 있다.
--   user_chests     사용자가 가진 상자. 같은 상자를 여러 개 가질 수 있어 unique 제약이 없다.
--                   opened_at 이 NULL 이면 아직 열지 않은 상자다.
--
-- chest_rewards.reward_type 은 quest_rewards.reward_type 과 같은 vocabulary 를 쓴다.
-- 단 'CHEST' 는 넣지 않는다. 상자 안의 상자는 지원하지 않고, lobby 도 이를 검사한다.
--
-- 상자 내용물은 제품 결정이고 chest_rewards 행으로 고친다. 상자에 보상을 더 넣으려면 행을
-- 더 넣으면 된다(예: MAGIC, DECORATION). 지금은 내용물이 고정이다. 무작위 추첨은 나중에
-- 컬럼을 더해 붙일 수 있고, 이 migration 은 만들지 않는다.
--   forest_chest   -> 'grass' 외형
--   fortress_chest -> 'golem' 외형
-- 외형은 id 가 아니라 appearances.key 로 찾고, 없으면 migration 이 실패한다.
--
-- 배포 순서: 이 migration 은 표만 추가하므로 lobby 보다 먼저 적용한다. 이 표를 읽는 lobby 가
-- 먼저 뜨면 쿼리가 실패한다. V020(appearances)이 먼저 적용되어 있어야 한다.
-- no-tags: this migration registers neither a game object nor a magic.

CREATE TABLE chests (
    id         bigserial PRIMARY KEY,
    key        varchar(32) NOT NULL UNIQUE,
    sort_order int NOT NULL DEFAULT 0
);

CREATE TABLE chest_rewards (
    id          bigserial PRIMARY KEY,
    chest_id    bigint      NOT NULL REFERENCES chests (id) ON DELETE CASCADE,
    reward_type varchar(31) NOT NULL,
    target_id   bigint,
    amount      int         NOT NULL DEFAULT 1 CHECK (amount > 0)
);

CREATE INDEX idx_chest_rewards_chest_id ON chest_rewards (chest_id);

CREATE TABLE user_chests (
    id          bigserial PRIMARY KEY,
    user_id     bigint      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    chest_id    bigint      NOT NULL REFERENCES chests (id),
    acquired_at timestamptz NOT NULL DEFAULT now(),
    opened_at   timestamptz
);

CREATE INDEX idx_user_chests_unopened ON user_chests (user_id) WHERE opened_at IS NULL;

INSERT INTO chests (key, sort_order) VALUES
    ('forest_chest', 0),
    ('fortress_chest', 1);

DO $$
DECLARE
    mapping record;
    chest_row_id bigint;
    appearance_row_id bigint;
BEGIN
    FOR mapping IN
        SELECT * FROM (VALUES ('forest_chest', 'grass'), ('fortress_chest', 'golem')) AS m (chest_key, appearance_key)
    LOOP
        SELECT id INTO chest_row_id FROM chests WHERE key = mapping.chest_key;

        SELECT id INTO appearance_row_id FROM appearances WHERE key = mapping.appearance_key;
        IF appearance_row_id IS NULL THEN
            RAISE EXCEPTION 'appearance % does not exist', mapping.appearance_key;
        END IF;

        INSERT INTO chest_rewards (chest_id, reward_type, target_id, amount)
        VALUES (chest_row_id, 'APPEARANCE', appearance_row_id, 1);
    END LOOP;
END $$;

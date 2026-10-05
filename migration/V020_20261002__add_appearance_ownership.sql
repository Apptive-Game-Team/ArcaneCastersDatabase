-- 사용자가 가진 외형을 기록하기 위해 appearances 와 user_appearances 를 추가한다.
-- V018 의 users.appearance 는 사용자가 지금 고른 외형 하나이고, 값은 client 의
-- Resources/PlayerAppearances/ 아래 디렉터리 이름이다. 이 migration 은 사용자가 가진 외형
-- 전체를 따로 기록한다. users.appearance 는 바꾸지 않고 FK 도 걸지 않는다. 허용 값을
-- application 이 정한다는 V018 의 결정을 그대로 둔다.
--
-- appearances 는 숫자 id 를 가진 catalog 표다. quest_rewards.target_id 가 bigint 이고,
-- reward_type 'APPEARANCE' 인 보상은 appearances.id 를 target_id 로 가리키기 때문이다.
-- key 는 디렉터리 이름이고 길이만 제한한다. 형식은 CHECK 로 막지 않는다.
--
-- 'default' 외형은 application 이 모든 사용자가 가진 것으로 취급하므로 user_appearances 에
-- 행을 만들지 않는다. appearances 에는 catalog 로서 'default' 행이 있다.
--
-- 기존 사용자는 지금 users.appearance 에 있는 외형(default 제외)의 행을 하나씩 받는다.
-- appearances 에 없는 값이 users.appearance 에 있으면 migration 이 실패한다.
--
-- 배포 순서: 이 migration 은 표만 추가하므로 lobby 보다 먼저 적용한다. 이 표를 읽는 lobby 가
-- 먼저 뜨면 쿼리가 실패한다.
-- no-tags: this migration registers neither a game object nor a magic.

CREATE TABLE appearances (
    id         bigserial PRIMARY KEY,
    key        varchar(32) NOT NULL UNIQUE,
    sort_order int NOT NULL DEFAULT 0
);

INSERT INTO appearances (key, sort_order) VALUES
    ('default', 0),
    ('storm', 1),
    ('blaze', 2),
    ('summoner', 3),
    ('golem', 4),
    ('grass', 5),
    ('tide', 6);

CREATE TABLE user_appearances (
    id            bigserial PRIMARY KEY,
    user_id       bigint NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    appearance_id bigint NOT NULL REFERENCES appearances (id) ON DELETE CASCADE,
    acquired_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, appearance_id)
);

CREATE INDEX idx_user_appearances_appearance_id ON user_appearances (appearance_id);

DO $$
DECLARE
    unknown_key varchar(32);
BEGIN
    SELECT u.appearance INTO unknown_key
    FROM users u
    WHERE NOT EXISTS (SELECT 1 FROM appearances a WHERE a.key = u.appearance)
    LIMIT 1;
    IF FOUND THEN
        RAISE EXCEPTION 'users.appearance value % has no appearances row', unknown_key;
    END IF;
END $$;

INSERT INTO user_appearances (user_id, appearance_id)
SELECT u.id, a.id
FROM users u
JOIN appearances a ON a.key = u.appearance
WHERE u.appearance <> 'default';

-- 모험 보상을 보물상자 하나로 모은다. 제품 결정은 두 가지다.
--   1. stage 를 클리어할 때마다 자동으로 주던 옛 보상(quest 5~10)을 없앤다.
--   2. 모험 보상은 모험 끝의 보물상자뿐이다. 플레이어가 상자를 직접 눌러 받고, lobby 가 열릴 때
--      자동으로 지급하지 않는다.
--
-- 1. quests.claim_mode 를 추가한다. 허용 값은 application 이 정하므로 CHECK 를 걸지 않는다.
--      'AUTO'    lobby 가 quest 를 검사할 때 조건이 채워지면 바로 지급한다. 기본값이다.
--      'MANUAL'  플레이어가 받기를 명시적으로 요청할 때만 지급한다.
--    condition_type 이 'ADVENTURE_CLEAR' 인 quest(V022 의 두 개)는 'MANUAL' 로 바꾼다.
--
-- 2. 옛 stage 클리어 보상 마법을 상자 안으로 옮긴다.
--      quest 5, 6, 7, 8 (forest stage, MAGIC 보상)   -> 'forest_chest'
--      quest 9, 10      (fortress stage, MAGIC 보상) -> 'fortress_chest'
--    각 quest 의 MAGIC 보상(target_id, amount)을 chest_rewards 에 그대로 복사한다. 결과는
--    forest_chest 가 기존 'grass' 외형 옆에 마법 48, 49, 50, 27 을, fortress_chest 가 기존
--    'golem' 외형 옆에 마법 83, 44 를 갖는 것이다. 여섯 quest 가 STAGE_CLEAR 이고 MAGIC 보상이
--    정확히 한 행씩인지 먼저 확인하고, 아니면 migration 이 실패한다. 같은 (chest_id, reward_type,
--    target_id) 행이 이미 있으면 다시 넣지 않으므로 다시 실행해도 행이 늘지 않는다.
--
-- 3. quest 5~10 의 access_type 을 'DEPRECATED' 로 바꾼다. 행은 지우지 않고 quest_rewards 와
--    user_quests 도 건드리지 않는다. 기록과 되돌리기를 위해서이고, application 은 DEPRECATED
--    quest 를 건너뛴다.
--      - 이미 이 quest 들을 완료하고 보상을 받은 플레이어는 받은 것을 그대로 갖는다.
--      - stage 를 클리어했지만 옛 보상을 아직 받지 못한 플레이어는 같은 마법을 이제 상자에서 받는다.
--
-- 배포 순서: 이 migration 을 새 lobby 보다 먼저 적용한다. 새 lobby 는 시작할 때 quests.claim_mode
-- 와 이 chain 의 표들을 읽으므로 이 컬럼이 없으면 뜨지 않는다. 적용한 뒤에도 옛 lobby 는 컬럼을
-- 모르지만, 모험 클리어 quest 는 progress_checker 가 NULL 이라 옛 lobby 가 건너뛰므로 깨지지
-- 않는다. 상자는 claim endpoint 를 가진 새 lobby 와 클릭 흐름을 가진 새 client 가 배포된 뒤에야
-- 받을 수 있다. V019~V022 가 먼저 적용되어 있어야 한다.
-- no-tags: this migration registers neither a game object nor a magic.

-- 1. claim_mode.
ALTER TABLE quests ADD COLUMN IF NOT EXISTS claim_mode varchar(10) NOT NULL DEFAULT 'AUTO';

UPDATE quests SET claim_mode = 'MANUAL' WHERE condition_type = 'ADVENTURE_CLEAR';

-- 2. 옛 보상을 상자로 옮긴다.
DO $$
DECLARE
    retired record;
    reward_count integer;
BEGIN
    FOR retired IN
        SELECT * FROM (VALUES (5), (6), (7), (8), (9), (10)) AS r (quest_id)
    LOOP
        IF NOT EXISTS (SELECT 1 FROM quests WHERE id = retired.quest_id AND condition_type = 'STAGE_CLEAR') THEN
            RAISE EXCEPTION 'quest % does not exist or is not a STAGE_CLEAR quest', retired.quest_id;
        END IF;

        SELECT count(*) INTO reward_count
        FROM quest_rewards
        WHERE quest_id = retired.quest_id AND reward_type = 'MAGIC';
        IF reward_count <> 1 THEN
            RAISE EXCEPTION 'quest % has % MAGIC quest_rewards rows, expected exactly 1', retired.quest_id, reward_count;
        END IF;
    END LOOP;
END $$;

DO $$
DECLARE
    mapping record;
    chest_row_id bigint;
BEGIN
    FOR mapping IN
        SELECT * FROM (VALUES
            (5, 'forest_chest'), (6, 'forest_chest'), (7, 'forest_chest'), (8, 'forest_chest'),
            (9, 'fortress_chest'), (10, 'fortress_chest')
        ) AS m (quest_id, chest_key)
    LOOP
        SELECT id INTO chest_row_id FROM chests WHERE key = mapping.chest_key;
        IF chest_row_id IS NULL THEN
            RAISE EXCEPTION 'chest % does not exist', mapping.chest_key;
        END IF;

        INSERT INTO chest_rewards (chest_id, reward_type, target_id, amount)
        SELECT chest_row_id, qr.reward_type, qr.target_id, qr.amount
        FROM quest_rewards qr
        WHERE qr.quest_id = mapping.quest_id
          AND qr.reward_type = 'MAGIC'
          AND NOT EXISTS (SELECT 1 FROM chest_rewards cr
                          WHERE cr.chest_id = chest_row_id
                            AND cr.reward_type = qr.reward_type
                            AND cr.target_id = qr.target_id);
    END LOOP;
END $$;

-- 3. 옛 quest 를 폐기한다.
UPDATE quests SET access_type = 'DEPRECATED' WHERE id IN (5, 6, 7, 8, 9, 10);

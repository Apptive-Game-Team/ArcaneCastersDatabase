-- 모험 하나를 모든 stage 클리어하면 외형을 보상으로 받는 quest 를 모험마다 하나씩 추가한다.
--   forest   -> 'grass' 외형
--   fortress -> 'golem' 외형
-- 이 대응은 제품 결정이다. 바꾸려면 quest_rewards 행의 target_id 를 고치는 migration 을 새로 쓴다.
--
-- quests 행은 condition_type 'ADVENTURE_CLEAR', condition_target_id 에 모험 id,
-- require_value 에 그 모험의 stage 수를 담는다. stage 수는 실행 시점의 stages 에서 센다.
-- progress_checker 와 reward_giver 는 일부러 NULL 로 둔다. V019 가 두 컬럼을 nullable 로
-- 바꿨고, 새 quest 는 옛 컬럼을 채우지 않는다. 옛 컬럼에는 'adventure_clear_pc' 같은 값에
-- 대응하는 옛 application 코드가 없다.
--
-- 모험은 id 가 아니라 name 으로, 외형은 key 로 찾는다. quests.id 는 sequence 로 받는다.
-- 이미 같은 (condition_type, condition_target_id) quest 가 있으면 quest 도 보상도 다시 넣지 않는다.
--
-- 배포 순서: ADVENTURE_CLEAR 조건과 APPEARANCE 보상은 lobby application 이 구현한다. lobby 는
-- 시작할 때 DEPRECATED 가 아닌 quest 의 조건이나 보상 type 을 모르면 즉시 실패하므로, 두 type 을
-- 등록한 lobby 를 먼저 배포한 환경에서만 이 migration 을 적용한다. V020 도 먼저 적용되어 있어야 한다.
-- no-tags: this migration registers neither a game object nor a magic.

-- quests.id 는 옛 migration 이 명시한 id 로 넣은 행이 있어 sequence 가 뒤처졌을 수 있다.
SELECT setval(pg_get_serial_sequence('quests', 'id'),
              greatest(coalesce((SELECT max(id) FROM quests), 1), 1),
              (SELECT count(*) > 0 FROM quests));

DO $$
DECLARE
    mapping record;
    adventure_row_id bigint;
    appearance_row_id bigint;
    stage_count integer;
    new_quest_id bigint;
BEGIN
    FOR mapping IN
        SELECT * FROM (VALUES ('forest', 'grass'), ('fortress', 'golem')) AS m (adventure_name, appearance_key)
    LOOP
        SELECT id INTO adventure_row_id FROM adventures WHERE name = mapping.adventure_name;
        IF adventure_row_id IS NULL THEN
            RAISE EXCEPTION 'adventure % does not exist', mapping.adventure_name;
        END IF;

        SELECT id INTO appearance_row_id FROM appearances WHERE key = mapping.appearance_key;
        IF appearance_row_id IS NULL THEN
            RAISE EXCEPTION 'appearance % does not exist', mapping.appearance_key;
        END IF;

        SELECT count(*) INTO stage_count FROM stages WHERE adventure_id = adventure_row_id;
        IF stage_count = 0 THEN
            RAISE EXCEPTION 'adventure % has no stages', mapping.adventure_name;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM quests
                       WHERE condition_type = 'ADVENTURE_CLEAR' AND condition_target_id = adventure_row_id) THEN
            INSERT INTO quests (condition_type, condition_target_id, require_value)
            VALUES ('ADVENTURE_CLEAR', adventure_row_id, stage_count)
            RETURNING id INTO new_quest_id;

            INSERT INTO quest_rewards (quest_id, reward_type, target_id, amount)
            VALUES (new_quest_id, 'APPEARANCE', appearance_row_id, 1);
        END IF;
    END LOOP;
END $$;

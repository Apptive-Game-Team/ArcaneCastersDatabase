-- V031: gives the gate adventure (id 3) its end-of-adventure reward, as V021, V022 and V024 did
-- for forest and fortress.
--   gate_chest   a chest with one APPEARANCE reward: the 'blaze' appearance, amount 1
--   quest        ADVENTURE_CLEAR for adventure 3 (condition_target_id = the adventure id,
--                require_value = its stage count, 2 after V030), reward one gate_chest
-- The quest uses claim_mode 'MANUAL' like the other two ADVENTURE_CLEAR quests (V024): the
-- player claims the chest. progress_checker and reward_giver stay NULL (V019).
-- The appearance is found by appearances.key and the adventure by name; a missing row fails the
-- migration. The quest id comes from the sequence.
-- Deploy order: apply after V030 (the stage count is read at run time) and V021-V024. These
-- are rows only; the lobby needs no change for them.
-- Idempotent: the chest, its reward and the quest are not inserted again when they exist.
-- no-tags: this migration registers neither a game object nor a magic.

INSERT INTO chests (key, sort_order)
VALUES ('gate_chest', (SELECT coalesce(max(sort_order), -1) + 1 FROM chests))
ON CONFLICT (key) DO NOTHING;

DO $$
DECLARE
    chest_row_id bigint;
    appearance_row_id bigint;
    adventure_row_id bigint;
    stage_count integer;
    new_quest_id bigint;
BEGIN
    SELECT id INTO chest_row_id FROM chests WHERE key = 'gate_chest';

    SELECT id INTO appearance_row_id FROM appearances WHERE key = 'blaze';
    IF appearance_row_id IS NULL THEN
        RAISE EXCEPTION 'appearance blaze does not exist';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM chest_rewards
                   WHERE chest_id = chest_row_id AND reward_type = 'APPEARANCE' AND target_id = appearance_row_id) THEN
        INSERT INTO chest_rewards (chest_id, reward_type, target_id, amount)
        VALUES (chest_row_id, 'APPEARANCE', appearance_row_id, 1);
    END IF;

    SELECT id INTO adventure_row_id FROM adventures WHERE name = 'gate';
    IF adventure_row_id IS NULL THEN
        RAISE EXCEPTION 'adventure gate does not exist';
    END IF;

    SELECT count(*) INTO stage_count FROM stages WHERE adventure_id = adventure_row_id;
    IF stage_count = 0 THEN
        RAISE EXCEPTION 'adventure gate has no stages';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM quests
                   WHERE condition_type = 'ADVENTURE_CLEAR' AND condition_target_id = adventure_row_id) THEN
        PERFORM setval(pg_get_serial_sequence('quests', 'id'),
                       greatest(coalesce((SELECT max(id) FROM quests), 1), 1),
                       (SELECT count(*) > 0 FROM quests));

        INSERT INTO quests (condition_type, condition_target_id, require_value, claim_mode)
        VALUES ('ADVENTURE_CLEAR', adventure_row_id, stage_count, 'MANUAL')
        RETURNING id INTO new_quest_id;

        INSERT INTO quest_rewards (quest_id, reward_type, target_id, amount)
        VALUES (new_quest_id, 'CHEST', chest_row_id, 1);
    END IF;
END $$;

SELECT setval('chests_id_seq', (SELECT max(id) FROM chests));
SELECT setval('chest_rewards_id_seq', (SELECT max(id) FROM chest_rewards));

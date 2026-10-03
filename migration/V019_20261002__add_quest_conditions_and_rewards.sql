-- Deploy order: this migration only ADDS, so it is safe to run before the application code
-- switches over.
--   1. Run this migration.
--   2. Deploy lobby and admin, which read condition_type, condition_target_id and
--      quest_rewards instead of progress_checker, reward_giver and reward_params.
--   3. A later migration drops reward_params, quests.progress_checker and
--      quests.reward_giver.
-- Until step 3 lands, any migration that inserts into quests must fill both the old
-- columns (progress_checker, reward_giver, reward_params) and the new ones
-- (condition_type, condition_target_id, quest_rewards), because old and new application
-- versions can both be running.
--
-- New condition and reward types are added in application code only, so condition_type and
-- reward_type carry no CHECK constraint on their value set.

-- 1. quests: condition_type and condition_target_id.
ALTER TABLE quests ADD COLUMN condition_type varchar(31);
ALTER TABLE quests ADD COLUMN condition_target_id bigint;

DO $$
DECLARE
    unknown_checker record;
BEGIN
    UPDATE quests SET condition_type = 'STAGE_CLEAR' WHERE progress_checker = 'stage_clear_pc';
    UPDATE quests SET condition_type = 'TOTAL_WIN' WHERE progress_checker = 'total_win_pc';

    SELECT id, progress_checker INTO unknown_checker FROM quests WHERE condition_type IS NULL LIMIT 1;
    IF FOUND THEN
        RAISE EXCEPTION 'quest % has unmapped progress_checker %', unknown_checker.id, unknown_checker.progress_checker;
    END IF;
END $$;

ALTER TABLE quests ALTER COLUMN condition_type SET NOT NULL;

-- New application code inserts quests without the old columns, so they must stay nullable.
ALTER TABLE quests ALTER COLUMN progress_checker DROP NOT NULL;
ALTER TABLE quests ALTER COLUMN reward_giver DROP NOT NULL;

-- 2. quest_rewards, backfilled from reward_params.
CREATE TABLE quest_rewards (
    id          bigserial PRIMARY KEY,
    quest_id    bigint      NOT NULL REFERENCES quests (id) ON DELETE CASCADE,
    reward_type varchar(31) NOT NULL,
    target_id   bigint,
    amount      integer     NOT NULL DEFAULT 1 CHECK (amount > 0)
);

CREATE INDEX idx_quest_rewards_quest_id ON quest_rewards (quest_id);
CREATE INDEX idx_quest_rewards_type_target ON quest_rewards (reward_type, target_id);

DO $$
DECLARE
    q record;
    target bigint;
    reward_amount integer;
BEGIN
    FOR q IN SELECT id, reward_giver FROM quests ORDER BY id LOOP
        IF q.reward_giver = 'card_rg' THEN
            CONTINUE; -- cards no longer exist; every card_rg quest is DEPRECATED
        ELSIF q.reward_giver = 'magic_rg' THEN
            SELECT value INTO target FROM reward_params WHERE quest_id = q.id AND name = 'magic_id';
            IF target IS NULL THEN
                RAISE EXCEPTION 'quest % (magic_rg) has no magic_id reward param', q.id;
            END IF;
            SELECT coalesce(max(value), 1) INTO reward_amount FROM reward_params WHERE quest_id = q.id AND name = 'count';
            INSERT INTO quest_rewards (quest_id, reward_type, target_id, amount)
            VALUES (q.id, 'MAGIC', target, reward_amount);
        ELSIF q.reward_giver = 'deco_rg' THEN
            SELECT value INTO target FROM reward_params WHERE quest_id = q.id AND name = 'decoration_id';
            IF target IS NULL THEN
                RAISE EXCEPTION 'quest % (deco_rg) has no decoration_id reward param', q.id;
            END IF;
            INSERT INTO quest_rewards (quest_id, reward_type, target_id, amount)
            VALUES (q.id, 'DECORATION', target, 1);
        ELSE
            RAISE EXCEPTION 'quest % has unmapped reward_giver %', q.id, q.reward_giver;
        END IF;
    END LOOP;
END $$;

SELECT setval(pg_get_serial_sequence('quest_rewards', 'id'),
              coalesce((SELECT max(id) FROM quest_rewards), 1),
              (SELECT count(*) > 0 FROM quest_rewards));

-- 3. user_quests: one row per (user, quest).
DELETE FROM user_quests WHERE user_id IS NULL OR quest_id IS NULL;

DELETE FROM user_quests older
USING user_quests keeper
WHERE older.user_id = keeper.user_id
  AND older.quest_id = keeper.quest_id
  AND older.id > keeper.id;

ALTER TABLE user_quests ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE user_quests ALTER COLUMN quest_id SET NOT NULL;
ALTER TABLE user_quests ADD CONSTRAINT uq_user_quests_user_quest UNIQUE (user_id, quest_id);

DO $$
DECLARE
    retired_id bigint;
    replacement_id bigint;
BEGIN
    SELECT id INTO STRICT retired_id FROM magics WHERE name = 'grass_generator';
    SELECT id INTO STRICT replacement_id FROM magics WHERE name = 'repair_totem' AND purpose = 'PLAYER';

    -- 매치 통계와 수령한 보상은 기존 마법 ID를 계속 참조한다.
    UPDATE magics
    SET purpose = 'LEGACY', access_type = 'NONE', updated_at = now()
    WHERE id = retired_id AND (purpose <> 'LEGACY' OR access_type <> 'NONE');

    INSERT INTO progression_magic_rewards (magic_id, faction, unlock_level)
    SELECT replacement_id, faction, unlock_level
    FROM progression_magic_rewards
    WHERE magic_id = retired_id
    ON CONFLICT DO NOTHING;

    DELETE FROM progression_magic_rewards WHERE magic_id = retired_id;

    UPDATE progression_reward_items item
    SET magic_id = replacement_id, reward_key = 'repair_totem'
    FROM progression_reward_claims claim
    WHERE item.claim_id = claim.id AND claim.claimed_at IS NULL AND item.magic_id = retired_id;

    -- 수리 토템을 우선 넣고, 덱당 3장 한도를 넘으면 같은 원소와 시전 방식의 카드를 우선 고른다.
    WITH replaced AS (
        INSERT INTO deck_cards (deck_id, magic_id, count)
        SELECT card.deck_id, replacement.id, card.count
        FROM deck_cards card
        JOIN decks deck ON deck.id = card.deck_id
        JOIN bot_personas bot ON bot.user_id = deck.user_id
        JOIN magics retired ON retired.id = card.magic_id
        CROSS JOIN LATERAL (
            SELECT candidate.id
            FROM magics candidate
            LEFT JOIN deck_cards existing
              ON existing.deck_id = card.deck_id AND existing.magic_id = candidate.id
            WHERE candidate.purpose = 'PLAYER' AND COALESCE(existing.count, 0) + card.count <= 3
            ORDER BY (candidate.id = replacement_id) DESC,
                     (candidate.element = retired.element) DESC,
                     (candidate.cast_kind = retired.cast_kind) DESC,
                     candidate.id
            LIMIT 1
        ) replacement
        WHERE card.magic_id = retired_id
        ON CONFLICT (magic_id, deck_id) DO UPDATE
        SET count = deck_cards.count + EXCLUDED.count
        RETURNING deck_id, magic_id
    )
    INSERT INTO user_magics (user_id, magic_id, count)
    SELECT DISTINCT deck.user_id, replaced.magic_id, 3
    FROM replaced
    JOIN decks deck ON deck.id = replaced.deck_id
    ON CONFLICT (user_id, magic_id) DO UPDATE SET count = GREATEST(user_magics.count, EXCLUDED.count);

    DELETE FROM balance_parameter_references
    WHERE game_object_id IN (SELECT id FROM game_objects WHERE name = 'grass_generator');

    DELETE FROM deck_cards WHERE magic_id = retired_id;
    DELETE FROM user_magics WHERE magic_id = retired_id;
END $$;

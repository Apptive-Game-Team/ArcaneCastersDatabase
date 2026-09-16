-- main 의 V100_20260915__remove_magics_the_server_cannot_cast.sql 를 magic-card 모델로 다시 쓴 것이다.
--
-- 분류 C. 지우는 대상 일곱 개와 이유는 원본 그대로다. 게임 서버가 magics 행 이름으로 bean 을 찾는데
-- 이 일곱에는 그 이름의 bean 이 없어서 기동할 때마다 경고를 남기고 건너뛴다.
--
--   fire_explosion, nature_explosion, rock_explosion   alias 표가 가리키는 대로 fire_explode,
--                                                      leaf_explode, rock_explode object 로 대체되었다
--   nature_shot, rock_shot                             실제로 나온 것은 vine_toss 와 rock_rolling 이다
--   wind_slime_swarm                                   클래스가 쓰인 적이 없다
--   pve_vine                                           손패에 오지 않는 PVE 전용 spawn 이다
--
-- V087 의 NOTICE 가 "게임 서버에 구현이 없어 Code 로 둔 magics" 로 이름을 남긴 그 행들이다.
--
-- magic-card 에 맞춰 세 군데를 고쳤다.
--
--   닿을 수 있는지 검사   원본은 magic_cards 행이 있으면 실패한다. 개편에는 조합이 없으므로 같은 뜻의
--                       검사는 "어느 deck 에 들어 있는가"다. deck_cards 는 V086 이 magics 로 옮겨
--                       두었고 fk_deck_cards_magic_id 에 ON DELETE 가 없어서, 한 장이라도 들어 있으면
--                       아래 DELETE 가 foreign key 위반으로 멈춘다. 먼저 읽을 수 있는 메시지로 실패한다.
--                       V086 이 기본 deck 을 mana_cost > 0 인 DEFAULT 마법으로만 채우고 이 일곱은
--                       조합이 없어 0 마나라, 지금은 어느 deck 에도 없어야 한다.
--   magics.game_object_id 원본은 game_objects 를 지우기 전에 이 column 으로 참조를 확인한다. magic-card
--                       에는 그 column 이 없다. 무엇을 만드는지는 magics.prefab 이 이름으로 들고 있으므로
--                       같은 뜻의 검사는 "어느 마법도 이 이름을 prefab 으로 쓰지 않는가"다.
--   parameter_values     원본에서 이 일곱의 game object 는 magic_id 행 하나만 들고 있었다. magic-card
--                       에서는 V084 가 모든 마법 이름에 mana_cost 와 range 행을 달았으므로 그 행들도
--                       같이 지워진다. object 가 마법과 함께 사라진다는 결과는 같다.
--
-- statistic_game_magics 행을 지우는 것은 되돌릴 수 없다. 그 경기는 실제로 있었고, 지운 뒤에는 어떤
-- 마법을 시전했는지 아무 데도 남지 않는다. user_magics, magic_tags, magic_cards 는 기존
-- ON DELETE CASCADE 가 지운다.

-- ------------------------------------------------------------------ 먼저 참이어야 하는 것
DO
$$
    DECLARE
        in_a_deck TEXT;
    BEGIN
        SELECT COALESCE(STRING_AGG(DISTINCT magic.name, ', ' ORDER BY magic.name), '')
        INTO in_a_deck
        FROM magics magic
                 JOIN deck_cards deck_card ON deck_card.magic_id = magic.id
        WHERE magic.name IN ('fire_explosion', 'nature_explosion', 'rock_explosion', 'nature_shot',
                             'rock_shot', 'wind_slime_swarm', 'pve_vine');

        IF in_a_deck <> '' THEN
            RAISE EXCEPTION 'these magics are in someone''s deck and are no longer unreachable: %', in_a_deck;
        END IF;
    END
$$;

-- --------------------------------------------------------------------------- the deletions
DELETE
FROM statistic_game_magics statistic
    USING magics magic
WHERE statistic.magic_id = magic.id
  AND magic.name IN ('fire_explosion', 'nature_explosion', 'rock_explosion', 'nature_shot',
                     'rock_shot', 'wind_slime_swarm', 'pve_vine');

DELETE
FROM magic_game_object_aliases alias
WHERE alias.magic_name IN ('fire_explosion', 'nature_explosion', 'rock_explosion', 'nature_shot',
                           'rock_shot', 'wind_slime_swarm', 'pve_vine');

-- 자리만 지키던 game object 와 거기 달린 parameter 행. game_objects 가 그 foreign key 의 부모라
-- parameter_values 를 먼저 지운다.
DELETE
FROM parameter_values parameter_value
    USING game_objects game_object
WHERE parameter_value.game_object_id = game_object.id
  AND game_object.name IN ('fire_explosion', 'nature_explosion', 'rock_explosion', 'nature_shot',
                           'rock_shot', 'wind_slime_swarm', 'pve_vine')
  AND NOT EXISTS (SELECT 1 FROM magics magic WHERE magic.prefab = game_object.name);

DELETE
FROM game_objects game_object
WHERE game_object.name IN ('fire_explosion', 'nature_explosion', 'rock_explosion', 'nature_shot',
                           'rock_shot', 'wind_slime_swarm', 'pve_vine')
  AND NOT EXISTS (SELECT 1 FROM parameter_values parameter_value
                  WHERE parameter_value.game_object_id = game_object.id)
  AND NOT EXISTS (SELECT 1 FROM game_object_tags tag
                  WHERE tag.game_object_id = game_object.id)
  AND NOT EXISTS (SELECT 1 FROM magics magic WHERE magic.prefab = game_object.name);

DELETE
FROM magics magic
WHERE magic.name IN ('fire_explosion', 'nature_explosion', 'rock_explosion', 'nature_shot',
                     'rock_shot', 'wind_slime_swarm', 'pve_vine');

-- --------------------------------------------------------------------------- assertions
DO
$$
    DECLARE
        survivors     TEXT;
        dangling_stat INTEGER;
        magic_count   INTEGER;
        broken_decks  INTEGER;
    BEGIN
        SELECT COALESCE(STRING_AGG(magic.name, ', ' ORDER BY magic.name), '')
        INTO survivors
        FROM magics magic
        WHERE magic.name IN ('fire_explosion', 'nature_explosion', 'rock_explosion', 'nature_shot',
                             'rock_shot', 'wind_slime_swarm', 'pve_vine');

        IF survivors <> '' THEN
            RAISE EXCEPTION 'these magics are still here: %', survivors;
        END IF;

        -- statistic_game_magics 에는 foreign key 가 없어서 이 불변식을 검사하는 곳이 여기뿐이다.
        SELECT COUNT(*)
        INTO dangling_stat
        FROM statistic_game_magics statistic
        WHERE NOT EXISTS (SELECT 1 FROM magics magic WHERE magic.id = statistic.magic_id);

        IF dangling_stat > 0 THEN
            RAISE EXCEPTION '% statistic rows name a magic that does not exist', dangling_stat;
        END IF;

        -- V086 이 세운 "deck 하나가 카드 15장" 을 이 삭제가 깨지 않았는지 본다. 위의 사전 검사가
        -- 통과했다면 한 장도 지워지지 않았어야 한다.
        SELECT COUNT(*)
        INTO broken_decks
        FROM (SELECT deck.id
              FROM decks deck
                       LEFT JOIN deck_cards deck_card ON deck_card.deck_id = deck.id
              GROUP BY deck.id
              HAVING COALESCE(SUM(deck_card.count), 0) <> 15) bad_deck;

        IF broken_decks > 0 THEN
            RAISE EXCEPTION '% deck(s) no longer hold 15 cards after the removal', broken_decks;
        END IF;

        SELECT COUNT(*) INTO magic_count FROM magics;
        RAISE NOTICE '% magics remain', magic_count;
    END
$$;

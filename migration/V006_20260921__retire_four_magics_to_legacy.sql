-- water_shot, fire_slime_nest, wind_explosion and lightning_shot become LEGACY, and every player
-- loses them.
--
-- The four are what is left of issue #12. In the card era a magic was a combination of cards, and
-- these four had no magic_cards rows, so nobody could assemble them and nobody could cast them.
-- The mana cost and the element of a magic were read from that combination, so all four still
-- carry element 'None' and a mana_cost of 0. After ownership moved to magics one row is one card,
-- and the card list serves the row as it stands: a card that costs no mana and can be cast as
-- often as the player likes. They are the last four rows in the whole table with mana_cost 0;
-- V003 already took water_slime_nest to LEGACY and pve_nature_slime_nest to PVE, and the other
-- seven rows from that issue no longer exist in magics at all.
--
-- What separates these four from water_slime_nest is that the game server does implement them:
-- WaterShotMagic, FireSlimeNestMagic, WindExplosionMagic and LightningShotMagic are all real
-- beans. So this is not a dead row being tidied away. A player who holds one of these can cast
-- it today, for free, and taking them back is a content decision, not a repair.
--
-- LEGACY rather than a DELETE of the rows: statistic_game_magics and statistic_game_decks point
-- at magics(id) and record matches that were really played. Removing the rows would either break
-- those foreign keys or erase that history.
--
-- Whether any of the four should come back as a proper card, with a mana cost and an element, is
-- a separate question. The implementations stay on the game server for that reason; nothing but
-- the row's purpose stops them from being cast.

UPDATE magics
SET purpose = 'LEGACY',
    access_type = 'NONE',
    updated_at = now()
WHERE name IN ('water_shot', 'fire_slime_nest', 'wind_explosion', 'lightning_shot')
  AND (purpose IS DISTINCT FROM 'LEGACY' OR access_type IS DISTINCT FROM 'NONE');

-- updated_at moves with the rows above. The lobby serves the magic list against a version taken
-- from max(updated_at) over the whole table, so a client that already cached the list would keep
-- showing these four as cards until some other row changed.

-- access_type 'NONE' stops the next account from receiving them. It does nothing about the
-- accounts that already hold them, and every account holds all four: they were 'DEFAULT', which
-- is what the lobby's grant on sign-up reads. Take them back here.
--
-- deck_cards goes with user_magics. Leaving the deck row would carry a free magic into matches,
-- which is the whole reason for this migration, and the lobby would reject the deck anyway:
-- DeckValidator fails a deck holding a card the player does not own.
--
-- The slot is left empty rather than filled with a substitute. Which card takes it is the
-- player's choice, and the deck editor asks for it: the client's save button stays disabled
-- while the deck reads 14 / 15, and lobby's DeckValidator wants exactly 15 both on save and at
-- the ranked queue, so a player whose deck lost a card cannot enqueue until they fill it.
-- Practice, PvE and bot matches do not run that check and keep working meanwhile. A substitute
-- chosen here would be the server picking a card for the player, and there is no honest choice
-- to make: these four have no element and no mana cost, so no card is the same card as any of
-- them.
DO
$$
    DECLARE
        deleted_user_magics INTEGER;
        deleted_deck_cards  INTEGER;
        short_decks         INTEGER;
    BEGIN
        DELETE FROM user_magics
        WHERE magic_id IN (SELECT id FROM magics WHERE purpose <> 'PLAYER');
        GET DIAGNOSTICS deleted_user_magics = ROW_COUNT;

        DELETE FROM deck_cards
        WHERE magic_id IN (SELECT id FROM magics WHERE purpose <> 'PLAYER');
        GET DIAGNOSTICS deleted_deck_cards = ROW_COUNT;

        SELECT count(*)
        INTO short_decks
        FROM (
            SELECT deck_id
            FROM deck_cards
            GROUP BY deck_id
            HAVING sum(count) <> 15
        ) AS decks_off_the_expected_size;

        RAISE NOTICE '% user_magics rows deleted for magics that are not player cards', deleted_user_magics;
        RAISE NOTICE '% deck_cards rows deleted for magics that are not player cards', deleted_deck_cards;
        RAISE NOTICE '% decks no longer hold 15 cards and have to be filled in the deck editor', short_decks;
    END
$$;

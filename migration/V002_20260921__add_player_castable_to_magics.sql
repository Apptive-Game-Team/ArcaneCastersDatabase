-- player_castable marks whether a player can put this magic in a deck and cast it. PvE and
-- bot-only rows (for example pve_nature_slime_nest) are false; the magic book listing and the
-- default-grant query must read this column instead of access_type, which only says whether a
-- castable magic ships to a new account for free and does not distinguish PvE rows from
-- player magics.

ALTER TABLE magics
    ADD COLUMN IF NOT EXISTS player_castable boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN magics.player_castable IS
    'Whether a player can hold this magic in a deck and cast it. False for PvE/bot-only rows; the magic book listing and the default-grant query read this column, not access_type.';

-- pve_nature_slime_nest is a PvE spawn, not a player magic, but access_type = 'DEFAULT' on it
-- only means "grant to every new player" and says nothing about PvE versus player-castable, so
-- today it both shows up in the magic book and is granted to new accounts. Update by name, and
-- guard on the current value so this is safe whether the row is already missing or already
-- false (migration rule 3).
UPDATE magics
SET player_castable = false
WHERE name = 'pve_nature_slime_nest'
  AND player_castable IS DISTINCT FROM false;

-- A magic that is no longer player-castable must not be left in a player's unlocked magic
-- list or a deck. Zero rows are expected against the current dev snapshot -- nothing
-- references pve_nature_slime_nest there -- but a production database may have granted or
-- decked it before this migration ran.
DO
$$
    DECLARE
        deleted_user_magics INTEGER;
        deleted_deck_cards  INTEGER;
    BEGIN
        DELETE FROM user_magics
        WHERE magic_id IN (SELECT id FROM magics WHERE player_castable = false);
        GET DIAGNOSTICS deleted_user_magics = ROW_COUNT;

        DELETE FROM deck_cards
        WHERE magic_id IN (SELECT id FROM magics WHERE player_castable = false);
        GET DIAGNOSTICS deleted_deck_cards = ROW_COUNT;

        RAISE NOTICE '% user_magics rows deleted for non-castable magics', deleted_user_magics;
        RAISE NOTICE '% deck_cards rows deleted for non-castable magics', deleted_deck_cards;
    END
$$;

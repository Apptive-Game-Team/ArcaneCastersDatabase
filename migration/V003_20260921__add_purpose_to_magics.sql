-- purpose says what a magics row is for. A row can be a player card, PvE and bot content, or a
-- leftover the game server no longer implements, and the three need different handling: only
-- PLAYER rows belong in the magic book and in a new account's grant.
--
-- access_type does not answer this. It says how a row reaches a player, which is a different
-- axis: a paid or unlockable player card is not 'DEFAULT' and still belongs in the book.
-- Overloading it would hide such a card the day one is added.
--
-- The two still have to agree. A row that is not a player card has no way to reach a player at
-- all, so this migration also moves those rows off 'DEFAULT' and onto 'NONE'. 'DEFAULT' on a PvE
-- row is what granted it to every new account in the first place.
--
-- The column is named purpose rather than kind because magics already carries cast_kind, and two
-- columns whose names differ by a prefix read as two halves of one value.

ALTER TABLE magics
    ADD COLUMN IF NOT EXISTS purpose varchar(16) NOT NULL DEFAULT 'PLAYER';

ALTER TABLE magics
    DROP CONSTRAINT IF EXISTS chk_magics_purpose;

ALTER TABLE magics
    ADD CONSTRAINT chk_magics_purpose CHECK (purpose IN ('PLAYER', 'PVE', 'LEGACY'));

COMMENT ON COLUMN magics.access_type IS
    'How this magic reaches a player: DEFAULT (granted to every new account) or NONE (never obtainable, for rows whose purpose is not PLAYER). Says nothing about whether the row belongs in the magic book; purpose answers that.';

COMMENT ON COLUMN magics.purpose IS
    'What this row is for: PLAYER (a card a player can hold and cast), PVE (PvE and bot content, never offered to a player), LEGACY (kept for history, not implemented on the game server). The magic book listing and the default-grant query take PLAYER only, and read this column rather than access_type.';

-- pve_nature_slime_nest is PvE content: the scenario spawns it through the
-- pve_nature_slime_nest_prefab initializer, and the game server has no magic bean of that name,
-- so a player who held it could not cast it. It reaches the magic book today only because the
-- listing reads the whole table, and it is granted to new accounts only because access_type says
-- 'DEFAULT'. Update by name and guard on the current value, so this is safe whether the row is
-- missing or already PVE (migration rule 3).
--
-- updated_at moves with it. There is no update trigger on magics, and the lobby serves the magic
-- list against a version taken from max(updated_at) over the whole table. Leaving the timestamp
-- alone would hide this row from that comparison, and every client that already cached the list
-- would keep showing the magic.
UPDATE magics
SET purpose = 'PVE',
    access_type = 'NONE',
    updated_at = now()
WHERE name = 'pve_nature_slime_nest'
  AND (purpose IS DISTINCT FROM 'PVE' OR access_type IS DISTINCT FROM 'NONE');

-- water_slime_nest is LEGACY. The game server carries no magic bean of that name either: the
-- slime nest family is fire, nature, rock, wind and lightning plus pve_water_slime_nest, and
-- this row is the only one of the six with no implementation behind it. A player holding it
-- could not cast it, so it comes out of the magic book and out of every player's list. Whether
-- the water nest should come back as a player card is a question about that whole family, and
-- LEGACY is the honest description until it is answered.
UPDATE magics
SET purpose = 'LEGACY',
    access_type = 'NONE',
    updated_at = now()
WHERE name = 'water_slime_nest'
  AND (purpose IS DISTINCT FROM 'LEGACY' OR access_type IS DISTINCT FROM 'NONE');

-- Moving the two rows off 'DEFAULT' stops the next account from receiving them; it does nothing
-- about the accounts that already hold them. Take them back here. Zero rows are expected against
-- the current dev snapshot -- nothing references either row there -- but a production database
-- may have granted or decked them before this migration ran.
DO
$$
    DECLARE
        deleted_user_magics INTEGER;
        deleted_deck_cards  INTEGER;
    BEGIN
        DELETE FROM user_magics
        WHERE magic_id IN (SELECT id FROM magics WHERE purpose <> 'PLAYER');
        GET DIAGNOSTICS deleted_user_magics = ROW_COUNT;

        DELETE FROM deck_cards
        WHERE magic_id IN (SELECT id FROM magics WHERE purpose <> 'PLAYER');
        GET DIAGNOSTICS deleted_deck_cards = ROW_COUNT;

        RAISE NOTICE '% user_magics rows deleted for magics that are not player cards', deleted_user_magics;
        RAISE NOTICE '% deck_cards rows deleted for magics that are not player cards', deleted_deck_cards;
    END
$$;

-- magic-card: ownership and deck contents move onto magics.
--
-- Ownership is two-sided today. user_cards holds three copies of each element and cast-type
-- card, and user_magics holds only whether a magic is unlocked, with no count at all. A deck
-- is deck_cards -> cards. Once one card is one magic, both sides point at magics and the
-- copy count lives in user_magics.
--
-- Three things happen here:
--
--   1. user_magics gains count, defaulting to 3. That is the number lobby's initUserCard
--      already grants per card, so nobody's collection changes size.
--   2. deck_cards.card_id becomes magic_id, with the foreign key moved from cards to magics
--      and the unique constraint reading (magic_id, deck_id).
--   3. Every deck's contents are rebuilt. The 15 rows a deck holds today are element and
--      cast-type cards, which have no meaning once the recipe is gone, and their ids would
--      survive the rename as magic ids pointing at unrelated magics. There is nothing to
--      convert, so the rows are replaced with a 15-card default deck built from DEFAULT
--      magics.
--
-- Step 3 is irreversible. A player's deck arrangement is not recoverable after this runs.
-- decks and users.selected_deck_id are untouched: the deck rows, their names and which one
-- each user has selected all stay, only the contents change.
--
-- The rebuild is tied to the rename rather than to the state of the deck contents. Old rows
-- hold cards.id values 1..11, and magics with those ids exist, so after the rename a stale
-- deck still satisfies every rule a validity check could ask about -- 15 rows, no more than
-- three copies, a magic_id that resolves. Only the presence of the card_id column separates
-- "not migrated yet" from "migrated, and since edited by its owner", so that is what the
-- rebuild is guarded on. A second run of this file finds no card_id column and leaves every
-- deck alone.

-- --------------------------------------------------------------------- copies per magic
--
-- ADD COLUMN with a DEFAULT writes the default into every existing row in the same
-- statement, so the "existing rows are filled with 3" requirement is met here and a
-- follow-up backfill guarded on IS NULL would find nothing to do. V085 relies on the same
-- behaviour in reverse: it adds updated_at without a default precisely so that its backfill
-- has rows to find.
ALTER TABLE user_magics
    ADD COLUMN IF NOT EXISTS count INTEGER NOT NULL DEFAULT 3;

-- ---------------------------------------------------------------- rebuild or leave alone
--
-- Recorded before the rename, because the rename is what erases the distinction.
CREATE TEMP TABLE deck_rebuild AS
SELECT EXISTS (SELECT 1
               FROM information_schema.columns
               WHERE table_schema = 'public'
                 AND table_name = 'deck_cards'
                 AND column_name = 'card_id') AS needed;

-- ------------------------------------------------------------------------ card_id -> magic_id
DO
$$
    BEGIN
        IF EXISTS (SELECT 1
                   FROM information_schema.columns
                   WHERE table_schema = 'public'
                     AND table_name = 'deck_cards'
                     AND column_name = 'card_id') THEN
            ALTER TABLE deck_cards
                RENAME COLUMN card_id TO magic_id;
            RAISE NOTICE 'renamed deck_cards.card_id to magic_id';
        ELSE
            RAISE NOTICE 'deck_cards.magic_id already exists; leaving the column alone';
        END IF;
    END
$$;

-- The foreign key to cards has to go before the rebuild inserts magic ids, or every row
-- whose magic id is not also a card id is rejected. Found by shape rather than by name:
-- V000 is a pg_catalog dump and the constraint carries whichever name that database
-- generated.
DO
$$
    DECLARE
        cards_foreign_key TEXT;
    BEGIN
        SELECT conname
        INTO cards_foreign_key
        FROM pg_constraint
        WHERE conrelid = 'deck_cards'::regclass
          AND contype = 'f'
          AND confrelid = 'cards'::regclass
        LIMIT 1;

        IF cards_foreign_key IS NULL THEN
            RAISE NOTICE 'deck_cards has no foreign key to cards';
        ELSE
            EXECUTE FORMAT('ALTER TABLE deck_cards DROP CONSTRAINT %I', cards_foreign_key);
            RAISE NOTICE 'dropped %, the deck_cards foreign key to cards', cards_foreign_key;
        END IF;
    END
$$;

-- ------------------------------------------------------------------- what goes in a deck
--
-- Five magics at three copies each. Three is the per-magic cap the deck rules already state,
-- so five kinds is the smallest deck that reaches 15, and a starter deck of five things to
-- learn is closer to the old template -- nine kinds, of which five were cast types that no
-- longer exist -- than a fifteen-kind deck would be.
--
-- Which five is derived, not listed. Only 19 of the ~69 recipes exist in this repository and
-- the rest are in the live database only, so a hardcoded list would be written against a
-- catalogue this repository cannot see.
--
--   access_type = 'DEFAULT'         what every user is granted at first login
--                                   (UserRepository.initUserMagic), so a deck built from
--                                   these is a deck its owner can cast
--   unlock_condition_type IS NULL   V085 leaves this empty on every magic, so nothing is
--                                   filtered today. The clause is here because V062 made
--                                   the same exclusion for the old template and a starter
--                                   deck opening with a locked card is the failure it
--                                   prevented
--   mana_cost > 0                   the exclusion V084 warned about. A magic with no recipe
--                                   summed an empty set and was priced at 0: dead names from
--                                   the V003 catalogue, and magics implemented on the game
--                                   server that were never given a recipe. They are
--                                   unreachable today, and putting one in the starter deck
--                                   would hand every player a free cast. The names are in
--                                   the NOTICE at the end
--
-- The order is a round robin over elements: the cheapest magic of each element first, then
-- the second cheapest of each, and so on. Taking the five cheapest outright could land five
-- magics of one element and fail the "two or more elements" deck rule. Ties inside an
-- element break on mana cost and then on name, so the choice is the same in every
-- environment holding the same catalogue. 'None' sorts last at each rank, so an element-less
-- magic is taken only when there is no coloured magic left at that rank.
CREATE TEMP TABLE default_deck_magic AS
WITH eligible AS (SELECT magic.id           AS magic_id,
                         magic.name         AS magic_name,
                         magic.element      AS element,
                         mana_cost.value    AS mana_cost
                  FROM magics magic
                           JOIN game_objects magic_object ON magic_object.name = magic.name
                           JOIN parameters mana_cost_parameter ON mana_cost_parameter.name = 'mana_cost'
                           JOIN parameter_values mana_cost
                                ON mana_cost.game_object_id = magic_object.id
                                    AND mana_cost.parameter_id = mana_cost_parameter.id
                  WHERE magic.access_type = 'DEFAULT'
                    AND magic.unlock_condition_type IS NULL
                    AND mana_cost.value > 0),
     ranked AS (SELECT eligible.*,
                       ROW_NUMBER() OVER (PARTITION BY element ORDER BY mana_cost, magic_name) AS rank_in_element
                FROM eligible)
SELECT magic_id, magic_name, element, mana_cost, 3 AS copies
FROM ranked
ORDER BY rank_in_element, (element = 'None'), mana_cost, magic_name
LIMIT 5;

-- Checked before anything is deleted, so a catalogue too small to build a legal deck aborts
-- the migration with every deck still intact rather than emptying them first.
DO
$$
    DECLARE
        chosen_count      INTEGER;
        chosen_total      INTEGER;
        chosen_max_copies INTEGER;
        chosen_elements   INTEGER;
    BEGIN
        SELECT COUNT(*),
               COALESCE(SUM(copies), 0),
               COALESCE(MAX(copies), 0),
               COUNT(DISTINCT element) FILTER (WHERE element <> 'None')
        INTO chosen_count, chosen_total, chosen_max_copies, chosen_elements
        FROM default_deck_magic;

        IF chosen_count <> 5 THEN
            RAISE EXCEPTION 'the default deck needs 5 eligible magics, found %; DEFAULT magics priced above 0 mana are too few to build a 15-card deck at 3 copies each',
                chosen_count;
        END IF;

        IF chosen_total <> 15 THEN
            RAISE EXCEPTION 'the default deck holds % cards, must hold 15', chosen_total;
        END IF;

        IF chosen_max_copies > 3 THEN
            RAISE EXCEPTION 'the default deck holds % copies of one magic, the cap is 3', chosen_max_copies;
        END IF;

        IF chosen_elements < 2 THEN
            RAISE EXCEPTION 'the default deck covers % element(s), the deck rules need 2 or more', chosen_elements;
        END IF;
    END
$$;

-- ------------------------------------------------------------------------- the rebuild
--
-- Every deck, including the user_id = 0 template that lobby copies into each new user
-- (UserRepository.initUserDeck) and every bot deck. A bot deck left holding card ids would
-- put the bot in a match with a hand of unrelated magics.
DELETE
FROM deck_cards
WHERE (SELECT needed FROM deck_rebuild);

INSERT INTO deck_cards(deck_id, magic_id, count)
SELECT deck.id, chosen.magic_id, chosen.copies
FROM decks deck
         CROSS JOIN default_deck_magic chosen
WHERE (SELECT needed FROM deck_rebuild)
ON CONFLICT (magic_id, deck_id) DO NOTHING;

-- A deck may now name a magic its owner never received. initUserMagic grants the DEFAULT
-- magics that existed the day the user first logged in, and every registration since --
-- V069 through V082 -- added a DEFAULT magic without granting it to anyone; that is what
-- scripts/manual/give_default_magics.sql exists to repair by hand. A deck holding a magic
-- its owner does not own is a hand the game server refuses to cast, so the gap is closed
-- for the magics that are actually in a deck.
--
-- The join to users is what keeps the template out: decks.user_id = 0 carries no users row
-- and user_magics.user_id is a foreign key to users.
INSERT INTO user_magics(user_id, magic_id, count)
SELECT DISTINCT deck.user_id, deck_card.magic_id, 3
FROM deck_cards deck_card
         JOIN decks deck ON deck.id = deck_card.deck_id
         JOIN users deck_owner ON deck_owner.id = deck.user_id
WHERE NOT EXISTS (SELECT 1
                  FROM user_magics owned
                  WHERE owned.user_id = deck.user_id
                    AND owned.magic_id = deck_card.magic_id);

-- --------------------------------------------------------------------------- constraints
--
-- Added after the rebuild, when no row holds a card id any more.
DO
$$
    BEGIN
        IF EXISTS (SELECT 1
                   FROM pg_constraint
                   WHERE conrelid = 'deck_cards'::regclass
                     AND contype = 'f'
                     AND confrelid = 'magics'::regclass) THEN
            RAISE NOTICE 'deck_cards already references magics';
        ELSE
            ALTER TABLE deck_cards
                ADD CONSTRAINT fk_deck_cards_magic_id FOREIGN KEY (magic_id) REFERENCES magics (id);
            RAISE NOTICE 'added fk_deck_cards_magic_id';
        END IF;
    END
$$;

-- The unique constraint V000 created covers (card_id, deck_id), which the rename already
-- turned into (magic_id, deck_id) -- the columns are right and only the generated name still
-- says card. Renaming it keeps one constraint instead of dropping and rebuilding an index
-- over the same pair. The second block is the fallback for a database whose constraint the
-- dump named something else; it checks the shape, following V083.
DO
$$
    BEGIN
        IF EXISTS (SELECT 1
                   FROM pg_constraint
                   WHERE conrelid = 'deck_cards'::regclass
                     AND conname = 'deck_cards_card_id_deck_id_key') THEN
            ALTER TABLE deck_cards
                RENAME CONSTRAINT deck_cards_card_id_deck_id_key TO uq_deck_cards_magic_id_deck_id;
            RAISE NOTICE 'renamed deck_cards_card_id_deck_id_key to uq_deck_cards_magic_id_deck_id';
        END IF;
    END
$$;

DO
$$
    DECLARE
        magic_id_attnum SMALLINT;
        deck_id_attnum  SMALLINT;
    BEGIN
        SELECT attnum INTO magic_id_attnum
        FROM pg_attribute
        WHERE attrelid = 'deck_cards'::regclass AND attname = 'magic_id';

        SELECT attnum INTO deck_id_attnum
        FROM pg_attribute
        WHERE attrelid = 'deck_cards'::regclass AND attname = 'deck_id';

        IF EXISTS (SELECT 1
                   FROM pg_index unique_index
                   WHERE unique_index.indrelid = 'deck_cards'::regclass
                     AND unique_index.indisunique
                     AND unique_index.indnatts = 2
                     AND ((unique_index.indkey[0] = magic_id_attnum AND unique_index.indkey[1] = deck_id_attnum)
                       OR (unique_index.indkey[0] = deck_id_attnum AND unique_index.indkey[1] = magic_id_attnum))) THEN
            RAISE NOTICE 'deck_cards is already unique on (magic_id, deck_id)';
        ELSE
            ALTER TABLE deck_cards
                ADD CONSTRAINT uq_deck_cards_magic_id_deck_id UNIQUE (magic_id, deck_id);
            RAISE NOTICE 'added uq_deck_cards_magic_id_deck_id';
        END IF;
    END
$$;

-- ------------------------------------------------------------------------- verification
DO
$$
    DECLARE
        deck_count           INTEGER;
        wrong_size_count     INTEGER;
        wrong_size_decks     TEXT;
        over_cap_count       INTEGER;
        unowned_count        INTEGER;
        template_deck_count  INTEGER;
        chosen_description   TEXT;
        priceless_count      INTEGER;
        priceless_names      TEXT;
        rebuilt              BOOLEAN;
    BEGIN
        SELECT needed INTO rebuilt FROM deck_rebuild;

        SELECT COUNT(*) INTO deck_count FROM decks;

        -- The completion condition of the issue: every deck holds 15 cards and no deck holds
        -- four copies of one magic. Checked over every deck, not only the selected ones, so a
        -- deck a user switches to later is legal too.
        SELECT COUNT(*),
               COALESCE(STRING_AGG(FORMAT('%s(%s)', bad_deck.deck_id, bad_deck.total), ', '
                                   ORDER BY bad_deck.deck_id), '')
        INTO wrong_size_count, wrong_size_decks
        FROM (SELECT deck.id                                       AS deck_id,
                     COALESCE(SUM(deck_card.count), 0)             AS total
              FROM decks deck
                       LEFT JOIN deck_cards deck_card ON deck_card.deck_id = deck.id
              GROUP BY deck.id
              HAVING COALESCE(SUM(deck_card.count), 0) <> 15) bad_deck;

        IF wrong_size_count > 0 THEN
            RAISE EXCEPTION '% deck(s) do not hold 15 cards: %', wrong_size_count, wrong_size_decks;
        END IF;

        SELECT COUNT(*) INTO over_cap_count FROM deck_cards WHERE deck_cards.count > 3;

        IF over_cap_count > 0 THEN
            RAISE EXCEPTION '% deck row(s) hold more than 3 copies of one magic', over_cap_count;
        END IF;

        SELECT COUNT(*) INTO template_deck_count FROM decks WHERE user_id = 0;

        IF template_deck_count <> 1 THEN
            RAISE EXCEPTION 'expected exactly one user_id = 0 template deck, found %', template_deck_count;
        END IF;

        -- Every magic in a deck owned by a real user must be in that user's collection, or
        -- the card is in the hand and cannot be cast.
        SELECT COUNT(*)
        INTO unowned_count
        FROM deck_cards deck_card
                 JOIN decks deck ON deck.id = deck_card.deck_id
                 JOIN users deck_owner ON deck_owner.id = deck.user_id
        WHERE NOT EXISTS (SELECT 1
                          FROM user_magics owned
                          WHERE owned.user_id = deck.user_id
                            AND owned.magic_id = deck_card.magic_id);

        IF unowned_count > 0 THEN
            RAISE EXCEPTION '% deck row(s) name a magic the deck owner does not own', unowned_count;
        END IF;

        SELECT STRING_AGG(FORMAT('%s [%s] %s mana x%s', chosen.magic_name, chosen.element,
                                 chosen.mana_cost, chosen.copies),
                          ', ' ORDER BY chosen.mana_cost, chosen.magic_name)
        INTO chosen_description
        FROM default_deck_magic chosen;

        -- The V084 warning, reported against the live catalogue. These are the DEFAULT magics
        -- kept out of the deck because no recipe ever priced them.
        SELECT COUNT(*), COALESCE(STRING_AGG(magic.name, ', ' ORDER BY magic.name), '(none)')
        INTO priceless_count, priceless_names
        FROM magics magic
                 JOIN game_objects magic_object ON magic_object.name = magic.name
                 JOIN parameters mana_cost_parameter ON mana_cost_parameter.name = 'mana_cost'
                 JOIN parameter_values mana_cost
                      ON mana_cost.game_object_id = magic_object.id
                          AND mana_cost.parameter_id = mana_cost_parameter.id
        WHERE magic.access_type = 'DEFAULT'
          AND mana_cost.value <= 0;

        IF rebuilt THEN
            RAISE NOTICE 'rebuilt the contents of % deck(s)', deck_count;
        ELSE
            RAISE NOTICE 'deck_cards was already migrated; left the contents of % deck(s) alone', deck_count;
        END IF;

        RAISE NOTICE 'default deck: %', chosen_description;
        RAISE NOTICE '% DEFAULT magic(s) excluded for costing 0 mana: %', priceless_count, priceless_names;
    END
$$;

DROP TABLE default_deck_magic;
DROP TABLE deck_rebuild;

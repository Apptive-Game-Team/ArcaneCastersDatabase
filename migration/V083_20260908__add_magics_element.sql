-- magic-card: magics becomes the card catalogue, so it needs a name it can be keyed by and
-- the element that used to live in the recipe.
--
-- Today a card is an element or a cast type and a magic is what a set of cards resolves to.
-- After the redesign one card is one magic, magic_cards and cards are dropped, and the only
-- part of the recipe that survives is the element. This migration adds magics.element and
-- fills it from the recipe while magic_cards is still there to read.
--
-- Element is derived, not chosen: the element card that appears most often in the recipe,
-- ties broken on the lower cards.id, and 'None' for a recipe with no element card. That is
-- the rule pinned in docs/magic-card.md, and computing it in SQL is the only way to reach
-- the ~50 magics whose recipe exists in the live database and not in this repository.
--
-- magics.name also becomes a key here. It is nullable and non-unique today, and every
-- registration migration has been guarding it by hand with WHERE NOT EXISTS. V084 keys
-- parameter_values off it and the game server will look magics up by name, so the guarantee
-- moves into the schema.

-- ---------------------------------------------------------------------------- name is a key
--
-- SET NOT NULL and ADD CONSTRAINT report a row count, not a name. Assert first so the failure
-- says which magic is the problem; repairing a duplicated name is a decision about which rows
-- statistic_game_magics and user_magics should follow, not something to guess at here.
DO
$$
    DECLARE
        null_name_count INTEGER;
        duplicate_names TEXT;
    BEGIN
        SELECT COUNT(*) INTO null_name_count FROM magics WHERE name IS NULL;

        IF null_name_count > 0 THEN
            RAISE EXCEPTION '% magics have no name; magics.name cannot be made NOT NULL', null_name_count;
        END IF;

        SELECT STRING_AGG(duplicate.name, ', ' ORDER BY duplicate.name)
        INTO duplicate_names
        FROM (SELECT name FROM magics WHERE name IS NOT NULL GROUP BY name HAVING COUNT(*) > 1) duplicate;

        IF duplicate_names IS NOT NULL THEN
            RAISE EXCEPTION 'these magic names are used by more than one row: %', duplicate_names;
        END IF;
    END
$$;

ALTER TABLE magics
    ALTER COLUMN name SET NOT NULL;

-- Checked on the shape -- any unique index over exactly (name) -- rather than on a constraint
-- name, following V061. A database that already carries one under a generated name keeps it.
DO
$$
    BEGIN
        IF EXISTS (SELECT 1
                   FROM pg_index unique_index
                   WHERE unique_index.indrelid = 'magics'::regclass
                     AND unique_index.indisunique
                     AND unique_index.indnatts = 1
                     AND unique_index.indkey[0] = (SELECT attnum
                                                   FROM pg_attribute
                                                   WHERE attrelid = 'magics'::regclass
                                                     AND attname = 'name')) THEN
            RAISE NOTICE 'magics.name is already unique; leaving the existing constraint in place';
        ELSE
            ALTER TABLE magics
                ADD CONSTRAINT uq_magics_name UNIQUE (name);
            RAISE NOTICE 'added uq_magics_name';
        END IF;
    END
$$;

-- ------------------------------------------------------------------------------- element
--
-- varchar(10) with a check constraint rather than a Postgres enum. The card_type enum is
-- being dropped by a later migration in this chain and the same shape is not worth
-- reintroducing: an enum needs ALTER TYPE ADD VALUE to grow, which cannot run in the same
-- transaction as the statements that use the new value.
ALTER TABLE magics
    ADD COLUMN IF NOT EXISTS element VARCHAR(10) NOT NULL DEFAULT 'None';

DO
$$
    BEGIN
        IF EXISTS (SELECT 1
                   FROM pg_constraint
                   WHERE conrelid = 'magics'::regclass
                     AND conname = 'chk_magics_element') THEN
            RAISE NOTICE 'chk_magics_element already exists';
        ELSE
            ALTER TABLE magics
                ADD CONSTRAINT chk_magics_element
                    CHECK (element IN ('Fire', 'Water', 'Lightning', 'Rock', 'Nature', 'Wind', 'None'));
            RAISE NOTICE 'added chk_magics_element';
        END IF;
    END
$$;

-- The backfill copies cards.name straight into magics.element, so an element card whose name
-- is outside the seven allowed values would abort on the check constraint with a message that
-- names the constraint and not the card. V001 seeds exactly six 'Type' cards and nothing has
-- added one since, so this is a guard against a live database that diverged, not an expected
-- state.
DO
$$
    DECLARE
        unexpected_element_cards TEXT;
    BEGIN
        SELECT STRING_AGG(card.name, ', ' ORDER BY card.name)
        INTO unexpected_element_cards
        FROM cards card
        WHERE card.card_type = 'Type'
          AND card.name NOT IN ('Fire', 'Water', 'Lightning', 'Rock', 'Nature', 'Wind');

        IF unexpected_element_cards IS NOT NULL THEN
            RAISE EXCEPTION 'these element cards have no matching magics.element value: %', unexpected_element_cards;
        END IF;
    END
$$;

-- Most recipes hold one element card, several hold the same one two or three times, and a few
-- mix two. COUNT(*) over magic_cards is the multiset count the parser already treats as the
-- recipe key, so a magic built from Water x3 counts Water three times.
--
-- DISTINCT ON with ORDER BY card_count DESC, card_id makes the tie rule part of the query
-- rather than a second pass: the lower cards.id wins, which is the seed order Fire, Water,
-- Lightning, Rock, Nature and then Wind at id 10.
--
-- Only rows still holding the default are written. A re-run recomputes nothing that was
-- already decided, and a recipe with no element card stays 'None' either way.
WITH element_card_counts AS (SELECT magic_card.magic_id,
                                    card.id                        AS card_id,
                                    card.name                      AS element_name,
                                    COUNT(*)                       AS card_count
                             FROM magic_cards magic_card
                                      JOIN cards card ON card.id = magic_card.card_id
                             WHERE card.card_type = 'Type'
                             GROUP BY magic_card.magic_id, card.id, card.name),
     dominant_element AS (SELECT DISTINCT ON (magic_id) magic_id, element_name
                          FROM element_card_counts
                          ORDER BY magic_id, card_count DESC, card_id)
UPDATE magics magic
SET element = dominant_element.element_name
FROM dominant_element
WHERE dominant_element.magic_id = magic.id
  AND magic.element = 'None';

-- Existing clients version the magic payload from magic_cards.updated_at, the same reason
-- V047 touched every recipe when it introduced cast_type. element joins that payload, so
-- cached copies have to be refreshed.
UPDATE magic_cards
SET updated_at = NOW();

DO
$$
    DECLARE
        element_counts        TEXT;
        unfilled_count        INTEGER;
        unfilled_names        TEXT;
        recipeless_count      INTEGER;
    BEGIN
        -- Every magic whose recipe holds an element card must have come out of the backfill
        -- with something other than 'None'. This is the assertion that the ~50 magics with no
        -- recipe SQL in this repository were reached, and it is the only place that can be
        -- checked, because the chain cannot be replayed on an empty database.
        SELECT COUNT(*), COALESCE(STRING_AGG(magic.name, ', ' ORDER BY magic.name), '')
        INTO unfilled_count, unfilled_names
        FROM magics magic
        WHERE magic.element = 'None'
          AND EXISTS (SELECT 1
                      FROM magic_cards magic_card
                               JOIN cards card ON card.id = magic_card.card_id
                      WHERE magic_card.magic_id = magic.id
                        AND card.card_type = 'Type');

        IF unfilled_count > 0 THEN
            RAISE EXCEPTION '% magics have an element card in their recipe but element None: %',
                unfilled_count, unfilled_names;
        END IF;

        SELECT COUNT(*)
        INTO recipeless_count
        FROM magics magic
        WHERE NOT EXISTS (SELECT 1 FROM magic_cards magic_card WHERE magic_card.magic_id = magic.id);

        SELECT STRING_AGG(FORMAT('%s=%s', tally.element, tally.magic_count), ', ' ORDER BY tally.element)
        INTO element_counts
        FROM (SELECT element, COUNT(*) AS magic_count FROM magics GROUP BY element) tally;

        RAISE NOTICE 'magics.element filled: %', element_counts;
        RAISE NOTICE '% magics have no recipe at all and keep element None', recipeless_count;
    END
$$;

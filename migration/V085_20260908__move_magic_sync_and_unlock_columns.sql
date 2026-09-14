-- magic-card: the columns the client sync and the card list read move onto magics.
--
-- Three columns that lobby reads live on tables this redesign deletes.
--
--   * The version string in GET /api/data/magics is max(magic_cards.updated_at). magic_cards
--     goes away with the recipe, so the client would lose the signal that tells it to refetch.
--   * The card list's unlock text ("3승", "1/3") reads cards.unlock_condition_type and
--     cards.unlock_required_value. cards goes away too.
--
-- Both move to magics, which is the card catalogue from V083 on.
--
-- magics.cast_type goes the other way. V047 added it and V084 has already read it into the
-- per-magic range and aim_shape parameter values, so nothing needs the column after this.
-- Dropping it is what "시전 종류를 없앤다" means at the schema level.

-- ------------------------------------------------------------------ sync timestamp
--
-- Added without a default. ADD COLUMN ... DEFAULT now() stamps every existing row in place,
-- and then a backfill has no NULL left to find and silently does nothing.
ALTER TABLE magics
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP;

-- Every magic is stamped with one fresh timestamp rather than carrying its recipe's timestamp
-- over. The client compares its cached version against max(updated_at) and only refetches when
-- that moves; carrying the old values over would leave the maximum exactly where the cached
-- version already is, because the old version was max(magic_cards.updated_at) over the same
-- rows. The response shape changes here - castType and cards leave, element, manaCost and
-- aimShape arrive - so a client that keeps its cached copy reads every magic as element 'None'.
-- A full refetch is the point, not a cost to avoid.
UPDATE magics SET updated_at = now() WHERE updated_at IS NULL;

ALTER TABLE magics
    ALTER COLUMN updated_at SET DEFAULT now();

ALTER TABLE magics
    ALTER COLUMN updated_at SET NOT NULL;

-- magic_cards carried idx_magic_cards_updated_at for the same max() query.
CREATE INDEX IF NOT EXISTS idx_magics_updated_at ON magics (updated_at);

-- --------------------------------------------------------------------- unlock rule
--
-- Left empty on purpose. cards.unlock_condition_type describes when an element card unlocks,
-- and no element card maps to one magic, so there is no value to carry over. Which magic
-- unlocks at how many wins is a content decision, made in the admin screens after this lands.
ALTER TABLE magics
    ADD COLUMN IF NOT EXISTS unlock_condition_type VARCHAR(31),
    ADD COLUMN IF NOT EXISTS unlock_required_value INTEGER;

-- --------------------------------------------------------------------- cast type out
ALTER TABLE magics
    DROP CONSTRAINT IF EXISTS chk_magics_cast_type;

ALTER TABLE magics
    DROP COLUMN IF EXISTS cast_type;

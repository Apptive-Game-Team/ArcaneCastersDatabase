-- spirit_bomb 의 beam 이 클릭한 지점에서 멈추지 않고 aim 방향으로 cast range(parameter range, 18)까지
-- 항상 뻗도록 game server 가 바뀐다. 이 파일은 그에 맞는 값 두 개를 바꾼다.
--
--   1. mana_cost 40 -> 25. beam 이 늘 끝까지 가므로 값을 낮춰 달라는 요청이 있었다.
--   2. magics.indicator 의 lane end 를 "aim" 에서 "target" 으로 바꾼다. client 에서 length 가 없는
--      caster lane 은 end "target" 일 때 aim 방향을 가리키고 magic 의 cast range 만큼 그려지므로,
--      새 server 동작과 indicator 가 같아진다.
--
-- mana_cost 는 magics.name 과 같은 이름의 game_objects 행에 붙어 있다. 행이 없으면 Parameters.getValue 가
-- 예외를 던져 경기가 그 자리에서 끝나므로, 이 파일은 update 만 하고 행이 없으면 먼저 막는다.
--
-- no-tags: magics 와 game_objects 에 새 행을 넣지 않는다. 기존 행의 값만 바꾼다.

DO
$$
    BEGIN
        IF NOT EXISTS (SELECT 1
                       FROM magics magic
                                JOIN game_objects object ON object.name = magic.name
                                JOIN parameter_values stored ON stored.game_object_id = object.id
                                JOIN parameters parameter ON parameter.id = stored.parameter_id
                           AND parameter.name = 'mana_cost'
                       WHERE magic.name = 'spirit_bomb') THEN
            RAISE EXCEPTION 'mana_cost row missing for: spirit_bomb';
        END IF;
    END
$$;

-- 값이 이미 같으면 아무것도 바꾸지 않는다. 그래서 다시 돌려도 updated_at 이 또 올라가지 않는다
-- (migration rule 3).
--
-- magics.updated_at 을 같이 올린다. lobby 의 MagicDataService 는 magic 목록의 version 을
-- max(magics.updated_at) 으로 만든다. 여기를 안 올리면 이미 목록을 받아 둔 client 는 version 이
-- 그대로라 옛 mana 와 indicator 를 계속 쓴다.
-- 한 문장 안에서 같은 magics 행을 두 번 고칠 수 없으므로 indicator 와 updated_at 을 한 update 로 합친다.
CREATE TEMP TABLE spirit_bomb_changed (changed boolean) ON COMMIT DROP;

WITH mana AS (
    UPDATE parameter_values stored
        SET value = 25,
            updated_at = now()
        FROM game_objects object,
            parameters parameter
        WHERE object.name = 'spirit_bomb'
            AND parameter.name = 'mana_cost'
            AND stored.game_object_id = object.id
            AND stored.parameter_id = parameter.id
            AND stored.value IS DISTINCT FROM 25::double precision
        RETURNING 1)
INSERT INTO spirit_bomb_changed
SELECT true FROM mana;

UPDATE magics
SET indicator  = '{"layers": [{"end": "target", "shape": "lane", "origin": "caster", "halfWidth": 0.75}], "version": 1}'::jsonb,
    updated_at = now()
WHERE name = 'spirit_bomb'
  AND (EXISTS (SELECT 1 FROM spirit_bomb_changed)
    OR indicator IS DISTINCT FROM
       '{"layers": [{"end": "target", "shape": "lane", "origin": "caster", "halfWidth": 0.75}], "version": 1}'::jsonb);

-- 끝난 뒤 두 값이 모두 새 값인지 확인한다.
DO
$$
    DECLARE
        mana_value double precision;
        end_value  text;
    BEGIN
        SELECT stored.value
        INTO mana_value
        FROM game_objects object
                 JOIN parameters parameter ON parameter.name = 'mana_cost'
                 JOIN parameter_values stored ON stored.game_object_id = object.id
            AND stored.parameter_id = parameter.id
        WHERE object.name = 'spirit_bomb';

        SELECT indicator -> 'layers' -> 0 ->> 'end' INTO end_value FROM magics WHERE name = 'spirit_bomb';

        IF mana_value IS DISTINCT FROM 25 OR end_value IS DISTINCT FROM 'target' THEN
            RAISE EXCEPTION 'spirit_bomb not updated: mana_cost=%, indicator end=%', mana_value, end_value;
        END IF;
    END
$$;

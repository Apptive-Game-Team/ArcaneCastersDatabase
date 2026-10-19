-- 정령 폭탄은 game server 에서 클릭한 지점을 향한 3D ray 로 바뀐다. 조준점이 비행 유닛 위에 있으면
-- 지면 위의 lane 만으로는 어디를 쏘는지 보이지 않으므로, lane layer 에 grounded false 를 붙인다.
-- client 는 grounded false 일 때 조준점 높이에 선을 하나 더 그린다. 기본값은 true 이고, 옛 client 는
-- 모르는 필드를 무시하므로 client 보다 먼저 배포해도 된다.
--
-- 바꾸는 값은 magics.indicator 의 layers[0] 에 붙는 grounded 하나다. 다른 layer 와 다른 필드는 건드리지 않는다.
-- layers[0] 의 shape 가 lane 이 아니면 아무것도 바꾸지 않는다.
--
-- no-tags: magics 와 game_objects 에 새 행을 넣지 않는다. 기존 행의 indicator 만 바꾼다.

-- 값이 이미 false 면 아무것도 바꾸지 않는다. 그래서 다시 돌려도 updated_at 이 또 올라가지 않는다
-- (migration rule 3).
--
-- magics.updated_at 을 같이 올린다. lobby 의 MagicDataService 는 magic 목록의 version 을
-- max(magics.updated_at) 으로 만든다. 여기를 안 올리면 이미 목록을 받아 둔 client 는 version 이
-- 그대로라 grounded 가 없는 옛 indicator 를 계속 쓴다.
UPDATE magics
SET indicator  = jsonb_set(indicator, '{layers,0,grounded}', 'false'::jsonb),
    updated_at = now()
WHERE name = 'spirit_bomb'
  AND indicator -> 'layers' -> 0 ->> 'shape' = 'lane'
  AND (indicator -> 'layers' -> 0 -> 'grounded') IS DISTINCT FROM 'false'::jsonb;

-- 끝난 뒤 lane layer 의 grounded 가 false 인지 확인한다.
DO
$$
    DECLARE
        grounded_value text;
    BEGIN
        SELECT indicator -> 'layers' -> 0 ->> 'grounded'
        INTO grounded_value
        FROM magics
        WHERE name = 'spirit_bomb';

        IF grounded_value IS DISTINCT FROM 'false' THEN
            RAISE EXCEPTION 'spirit_bomb indicator not updated: layers[0].grounded=%', grounded_value;
        END IF;
    END
$$;

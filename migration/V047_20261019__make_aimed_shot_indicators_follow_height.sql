-- 아래 9개 마법은 game server 에서 클릭한 좌표를 높이까지 포함해 3D 로 겨눈다. 비행 유닛을 눌러 시전하면
-- client 가 그 유닛의 높이를 보내므로 투사체나 빔이 위로 올라간다. 지면 위의 lane 만으로는 그게 보이지
-- 않으므로 lane layer 에 grounded false 를 붙인다. client 는 grounded false 일 때 조준점 높이로 올라가는
-- 선을 하나 더 그린다. 기본값은 true 이고, 옛 client 는 모르는 필드를 무시하므로 client 보다 먼저
-- 배포해도 된다.
--
--   spirit_bomb      SpiritBombChannel 이 3D ray 를 쏜다
--   fire_shot, lightning_shot, water_shot, chain_lightning, tide_call, boulder_strike, wind_blade
--                    Shot 계열이 setTarget 의 3D 방향으로 날아간다
--   will_o_wisp      MindControlShot 이 3D 방향으로 날아간다
--
-- 넣지 않은 lane 마법: rock_rolling 은 RollingRock 이 높이를 0 으로 눌러 바닥으로 구르고, vine_toss 는
-- 바닥에 넝쿨을 까는 마법이다. wind_totem 과 dragon_tower 의 lane 은 end forward 라 높이와 무관하다.
--
-- 바꾸는 값은 magics.indicator 의 layers[0] 에 붙는 grounded 하나다. 9개 모두 lane 이 layers[0] 이다.
-- 다른 layer 와 다른 필드는 건드리지 않는다. layers[0] 의 shape 가 lane 이 아니면 아무것도 바꾸지 않는다.
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
WHERE name IN ('spirit_bomb', 'fire_shot', 'lightning_shot', 'water_shot', 'chain_lightning',
               'tide_call', 'boulder_strike', 'wind_blade', 'will_o_wisp')
  AND indicator -> 'layers' -> 0 ->> 'shape' = 'lane'
  AND (indicator -> 'layers' -> 0 -> 'grounded') IS DISTINCT FROM 'false'::jsonb;

-- 끝난 뒤 9개 모두 lane layer 의 grounded 가 false 인지 확인한다.
DO
$$
    DECLARE
        missing text;
    BEGIN
        SELECT string_agg(expected.name, ', ' ORDER BY expected.name)
        INTO missing
        FROM unnest(ARRAY['spirit_bomb', 'fire_shot', 'lightning_shot', 'water_shot', 'chain_lightning',
                          'tide_call', 'boulder_strike', 'wind_blade', 'will_o_wisp']) AS expected(name)
                 LEFT JOIN magics m ON m.name = expected.name
        WHERE m.indicator -> 'layers' -> 0 ->> 'grounded' IS DISTINCT FROM 'false';

        IF missing IS NOT NULL THEN
            RAISE EXCEPTION 'indicator grounded not set to false for: %', missing;
        END IF;
    END
$$;

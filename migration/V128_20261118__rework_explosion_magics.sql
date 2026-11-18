-- no-tags: 기존 마법과 오브젝트의 수치를 조정하며 새 오브젝트는 등록하지 않는다.
CREATE TEMP TABLE explosion_balance (
    object_name text NOT NULL,
    parameter_name text NOT NULL,
    value double precision NOT NULL,
    PRIMARY KEY (object_name, parameter_name)
) ON COMMIT DROP;

INSERT INTO explosion_balance VALUES
    ('lightning_explosion', 'mana_cost', 10),
    ('electric_explode', 'radius', 1),
    ('electric_explode', 'damage', 90),
    ('magma_explosion', 'mana_cost', 30),
    ('magma_explosion', 'radius', 1),
    ('magma_explosion', 'damage', 350),
    ('magma_explosion', 'trigger_delay', 3),
    ('overgrowth', 'mana_cost', 20),
    ('overgrowth', 'radius', 1),
    ('overgrowth', 'damage', 20),
    ('razor_gale', 'mana_cost', 20),
    ('razor_gale', 'radius', 2),
    ('razor_gale', 'damage', 30),
    ('razor_gale', 'duration', 5),
    ('razor_gale', 'attack_interval', 1),
    ('sand_storm', 'mana_cost', 40),
    ('sand_storm', 'radius', 2),
    ('sand_storm', 'damage', 35),
    ('sand_storm', 'duration', 10),
    ('sand_storm', 'slow_percent', 0.5),
    ('water_explosion', 'mana_cost', 10),
    ('water_explosion', 'radius', 0.5),
    ('water_explosion', 'damage', 60),
    ('rock_blast', 'mana_cost', 20),
    ('rock_blast', 'damage', 150),
    ('rock_explode', 'radius', 1),
    ('rock_explode', 'damage', 150),
    ('rock_explode', 'medium_blast_radius', 1.5),
    ('rock_explode', 'medium_blast_damage', 350),
    ('vine_world', 'mana_cost', 50),
    ('giant_vine', 'damage', 350),
    ('vine', 'damage', 70);

DO $$
DECLARE missing text;
BEGIN
    SELECT string_agg(DISTINCT balance.object_name, ', ')
    INTO missing
    FROM explosion_balance balance
    WHERE NOT EXISTS (SELECT 1 FROM game_objects object WHERE object.name = balance.object_name);
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'Missing explosion game objects: %', missing;
    END IF;
END $$;

INSERT INTO parameters(name)
SELECT DISTINCT parameter_name FROM explosion_balance
ON CONFLICT (name) DO NOTHING;

CREATE TEMP TABLE explosion_changed ON COMMIT DROP AS
SELECT EXISTS (
    SELECT 1 FROM explosion_balance balance
    JOIN game_objects object ON object.name = balance.object_name
    JOIN parameters parameter ON parameter.name = balance.parameter_name
    LEFT JOIN parameter_values stored ON stored.game_object_id = object.id
        AND stored.parameter_id = parameter.id
    WHERE stored.value IS DISTINCT FROM balance.value
) AS changed;

INSERT INTO parameter_values AS stored (game_object_id, parameter_id, value)
SELECT object.id, parameter.id, balance.value
FROM explosion_balance balance
JOIN game_objects object ON object.name = balance.object_name
JOIN parameters parameter ON parameter.name = balance.parameter_name
ON CONFLICT (parameter_id, game_object_id) DO UPDATE
SET value = EXCLUDED.value, updated_at = now()
WHERE stored.value IS DISTINCT FROM EXCLUDED.value;

-- indicator JSON은 기존 parameter 참조를 유지한다. 돌 선택 반경과 덩굴 배치는 바꾸지 않는다.
-- magics의 갱신 시각도 바꿔 클라이언트가 변경된 수치를 다시 받게 한다.
UPDATE magics SET updated_at = now()
WHERE name IN ('lightning_explosion', 'magma_explosion', 'overgrowth', 'razor_gale',
               'sand_storm', 'water_explosion', 'rock_blast', 'vine_world')
  AND (SELECT changed FROM explosion_changed);

UPDATE magics
SET purpose = 'LEGACY', access_type = 'NONE', updated_at = now()
WHERE name = 'shock_overload'
  AND (purpose IS DISTINCT FROM 'LEGACY' OR access_type IS DISTINCT FROM 'NONE');

-- 기존 보유분과 덱에서도 회수한다. 경기 통계가 참조하는 magics 행은 남긴다.
DELETE FROM deck_cards WHERE magic_id IN (SELECT id FROM magics WHERE name = 'shock_overload');
DELETE FROM user_magics WHERE magic_id IN (SELECT id FROM magics WHERE name = 'shock_overload');

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM explosion_balance balance
        LEFT JOIN game_objects object ON object.name = balance.object_name
        LEFT JOIN parameters parameter ON parameter.name = balance.parameter_name
        LEFT JOIN parameter_values stored ON stored.game_object_id = object.id
            AND stored.parameter_id = parameter.id
        WHERE stored.value IS DISTINCT FROM balance.value
    ) THEN
        RAISE EXCEPTION 'Explosion balance values were not applied';
    END IF;
END $$;

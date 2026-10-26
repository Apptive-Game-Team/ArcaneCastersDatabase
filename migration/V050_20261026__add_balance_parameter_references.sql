-- no-tags: 관리자 시트 계산용 참조이며 game object나 magic을 등록하지 않습니다.
CREATE TABLE balance_parameter_references (
    game_object_id bigint NOT NULL REFERENCES game_objects(id) ON DELETE CASCADE,
    parameter_name varchar(128) NOT NULL CHECK (parameter_name ~ '^[a-z][a-z0-9_]*$'),
    target_game_object_id bigint NOT NULL REFERENCES game_objects(id) ON DELETE CASCADE,
    target_parameter_name varchar(128) NOT NULL CHECK (target_parameter_name ~ '^[a-z][a-z0-9_]*$'),
    multiplier double precision NOT NULL DEFAULT 1 CHECK (multiplier > 0 AND multiplier < 'Infinity'::double precision),
    PRIMARY KEY (game_object_id, parameter_name),
    CHECK (game_object_id <> target_game_object_id OR parameter_name <> target_parameter_name)
);

COMMENT ON TABLE balance_parameter_references IS '관리자 밸런스 시트 표시·계산용 참조. 전투 코드는 이 테이블을 읽지 않는다.';

-- 각 PrefabInitializer와 SprayingAttacker에서 확인한 출처입니다.
-- 공격 사거리나 유닛 충돌 반지름을 광역 피해 반지름으로 추측하지 않습니다.
INSERT INTO balance_parameter_references
    (game_object_id, parameter_name, target_game_object_id, target_parameter_name, multiplier)
SELECT source.id, ref.parameter_name, target.id, ref.target_parameter_name, ref.multiplier
FROM (VALUES
    ('lightning_cloud', 'damage', 'lightning_drop', 'damage', 1.0),
    ('lightning_cloud', 'effect_radius', 'lightning_drop', 'radius', 1.0),
    ('bean_shooter', 'projectile_speed', 'bean', 'speed', 1.0),
    ('bean_shooter', 'projectile_radius', 'bean', 'radius', 1.0),
    ('water_slime', 'attack_range', 'aqua_archer', 'attack_range', 1.0),
    ('grass_generator', 'leaf_field_radius', 'leaf_field', 'radius', 1.0),
    ('lightning_cloud', 'attack_area_radius', 'lightning_drop', 'radius', 1.0),
    ('magma_spirit', 'attack_area_radius', 'magma_fist', 'radius', 1.0),
    ('magma_spirit', 'damage', 'magma_fist', 'damage', 1.0),
    ('firework_tower', 'attack_area_radius', 'firework_shell', 'radius', 1.0),
    ('firework_tower', 'damage', 'firework_shell', 'damage', 1.0),
    ('crater_carrier', 'attack_area_radius', 'crater_shell', 'radius', 1.0),
    ('fire_spirit', 'attack_area_radius', 'fire_spirit', 'attack_range', 0.5)
) AS ref(object_name, parameter_name, target_object_name, target_parameter_name, multiplier)
JOIN game_objects source ON source.name = ref.object_name
JOIN game_objects target ON target.name = ref.target_object_name
WHERE EXISTS (SELECT 1 FROM parameter_values pv JOIN parameters p ON p.id = pv.parameter_id
              WHERE pv.game_object_id = target.id AND p.name = ref.target_parameter_name)
ON CONFLICT (game_object_id, parameter_name) DO NOTHING;

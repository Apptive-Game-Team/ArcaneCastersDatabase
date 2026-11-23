-- 카탈로그 등록과 기존 계정 지급 사이에 새 세력 선택이 확정되지 않도록 한다.
LOCK TABLE player_progression IN SHARE MODE;

INSERT INTO appearances (key, sort_order)
VALUES ('corrupted_finn', 7)
ON CONFLICT (key) DO NOTHING;

INSERT INTO user_appearances (user_id, appearance_id)
SELECT p.user_id, a.id
FROM player_progression p
CROSS JOIN appearances a
WHERE p.faction = 'HELL' AND a.key = 'corrupted_finn'
ON CONFLICT (user_id, appearance_id) DO NOTHING;

UPDATE users u
SET appearance = 'corrupted_finn'
FROM player_progression p
WHERE p.user_id = u.id
  AND p.faction = 'HELL'
  AND (u.appearance IS NULL OR u.appearance = 'default');

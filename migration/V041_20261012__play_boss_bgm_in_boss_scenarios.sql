-- 보스가 경기 시작부터 배치된 PVE 시나리오 5개의 intro 이벤트에 PlayBgm boss action 을 넣는다.
--
--   scenario  stage  보스 installer  prefab          intro 이벤트 기존 action
--   4         1      witch          PveVineWitch    없음
--   10        3      golem          WallGolem       없음
--   13        4      witch          PveVineWitch    1개 (action_order 1)
--   17        6      corrupted      PveEvilEnt      없음
--   18        6      corrupted      PveEvilEnt      없음
--
-- 다섯 보스 모두 pve_scenario_installers 로 처음부터 놓이므로, 보스전 곡은 intro (SecondsGte 1) 에서
-- 바로 시작한다. client 는 BgmContainer.prefab 의 bgmEntries 에서 boss key 로 곡을 찾는다
-- (ArcaneCastersClient PR #296). 일반 전투 곡은 바꾸지 않는다.
--
-- action_order 는 그 이벤트의 기존 최댓값 + 1 이라서, 대사와 기존 action 다음에 곡이 바뀐다.
-- 같은 이벤트에 PlayBgm boss 가 이미 있으면 넣지 않아 다시 돌려도 행이 늘지 않는다.
--
-- no-tags: game_objects 나 magics 행을 등록하지 않는다.

DO
$$
    DECLARE
        missing integer;
    BEGIN
        SELECT 5 - count(*) INTO missing
        FROM pve_scenario_events
        WHERE event_id = 'intro'
          AND scenario_id IN (4, 10, 13, 17, 18);
        IF missing <> 0 THEN
            RAISE EXCEPTION 'intro event missing in % of the 5 boss scenarios', missing;
        END IF;
    END
$$;

INSERT INTO pve_scenario_event_actions (event_row_id, action_order, action_type, bgm_key)
SELECT e.id,
       coalesce((SELECT max(a.action_order) FROM pve_scenario_event_actions a WHERE a.event_row_id = e.id), 0) + 1,
       'PlayBgm',
       'boss'
FROM pve_scenario_events e
WHERE e.event_id = 'intro'
  AND e.scenario_id IN (4, 10, 13, 17, 18)
  AND NOT EXISTS (SELECT 1
                  FROM pve_scenario_event_actions a
                  WHERE a.event_row_id = e.id
                    AND a.action_type = 'PlayBgm'
                    AND a.bgm_key = 'boss');

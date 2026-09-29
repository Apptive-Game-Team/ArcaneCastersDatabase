-- V015: registers the colony (scenario 3) and the keep gate (scenario 11) as objectives of
-- their Survive scenarios. The game server (ArcaneCastersGame issue #61) now also clears a
-- Survive scenario when every objective is destroyed. These two scenarios had no objective
-- rows, so destroying the colony / keep gate did not end the match before the 90 s / 100 s
-- timer. Issue #53.
-- no-tags: no game_objects or magics row is registered here.

INSERT INTO pve_scenario_objectives (installer_id, sort_order, scenario_id)
SELECT v.installer_id, v.sort_order, v.scenario_id
FROM (VALUES
    ('colony', 1, 3),
    ('keep_gate', 1, 11)
) AS v(installer_id, sort_order, scenario_id)
WHERE NOT EXISTS (
    SELECT 1 FROM pve_scenario_objectives o
    WHERE o.scenario_id = v.scenario_id AND o.installer_id = v.installer_id
);

SELECT setval('pve_scenario_objectives_id_seq', (SELECT max(id) FROM pve_scenario_objectives));

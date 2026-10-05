-- V032: adds the parameter spawn_height = 3.0 to the seven aerial summoned objects, so the Unity
-- client can tell an airborne summon from a ground one. 3.0 is GameConfig.AERIAL_MOB_INIT_HEIGHT
-- in the game server, the height these prefabs start at (ZPhysics initial z).
--   bomb_sprite, bubble_spirit, cloud_dragon, fire_lord_spirit, thunder_spirit, wind_spirit,
--   thunder_bird (the object thunder_bird_swarm spawns, see magic_game_object_aliases)
-- Deploy order: independent of the game server; the client treats a missing row as ground.
-- Idempotent: parameters use ON CONFLICT DO NOTHING and parameter_values use ON CONFLICT, a
-- second run resets the value.
-- no-tags: this migration registers neither a game object nor a magic.

INSERT INTO parameters(name)
VALUES ('spawn_height')
ON CONFLICT (name) DO NOTHING;

WITH desired_values(object_name, value) AS (
    VALUES
        ('bomb_sprite', 3.0),
        ('bubble_spirit', 3.0),
        ('cloud_dragon', 3.0),
        ('fire_lord_spirit', 3.0),
        ('thunder_spirit', 3.0),
        ('wind_spirit', 3.0),
        ('thunder_bird', 3.0)
)
INSERT INTO parameter_values(game_object_id, parameter_id, value)
SELECT go.id, p.id, dv.value
FROM desired_values dv
JOIN game_objects go ON go.name = dv.object_name
JOIN parameters p ON p.name = 'spawn_height'
ON CONFLICT (parameter_id, game_object_id)
DO UPDATE SET value = EXCLUDED.value, updated_at = now();

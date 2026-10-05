-- V025: clears the speaker of forest scenario 1's intro event. Its line, "Slimes are pouring out
-- of that nest. Break it!", is a hint to the player, but V013 set speaker_installer_id to the
-- enemy nest, so the client showed it as the nest talking. Without a speaker the client shows
-- the line as a neutral top banner.
-- Idempotent: after the first run no row matches the WHERE clause.
-- no-tags: no game_objects or magics row is registered here.
UPDATE pve_scenario_events
SET speaker_installer_id = NULL
WHERE scenario_id = 1
  AND event_id = 'intro'
  AND speaker_installer_id = 'nest';

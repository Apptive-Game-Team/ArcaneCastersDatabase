-- V026: adds pve_scenario_shields, which lets a scenario make one installer immune while other
-- installers stay alive. A row (scenario_id, installer_id, source_installer_id) means: the
-- shielded installer (installer_id) takes no damage while at least one of its source
-- installers (source_installer_id) is installed and not yet destroyed. Once every source of a
-- shielded installer is destroyed, the shield is down and the installer takes damage normally.
-- A shielded installer may list several sources (one row each). Issue #72.
-- Deploy order: the game server reads this table, so apply this migration before starting a
-- game server version that reads it. No content rows here - the first user is V027.
-- no-tags: no game_objects or magics row is registered here.

CREATE TABLE IF NOT EXISTS pve_scenario_shields (
    scenario_id         bigint      NOT NULL REFERENCES scenarios (id) ON DELETE CASCADE,
    installer_id        varchar(50) NOT NULL,
    source_installer_id varchar(50) NOT NULL,
    PRIMARY KEY (scenario_id, installer_id, source_installer_id)
);

COMMENT ON TABLE pve_scenario_shields IS
    'The shielded installer (installer_id) takes no damage while at least one of its source installers (source_installer_id) is installed and not yet destroyed.';

COMMENT ON COLUMN pve_scenario_shields.installer_id IS
    'The shielded installer.';

COMMENT ON COLUMN pve_scenario_shields.source_installer_id IS
    'An installer that keeps the shield up while it is alive.';

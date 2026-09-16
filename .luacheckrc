std = "lua51"
max_line_length = 120
self = false

exclude_files = { ".release/", "libs/" }

globals = {
  "ClassicAndyUIDB",
  "SLASH_CLASSICANDYUI1",
  "SLASH_CLASSICANDYUI2",
  "SlashCmdList",
  "StaticPopupDialogs",
}

read_globals = {
  -- WoW API
  "CreateFrame",
  "InCombatLockdown",
  "ReloadUI",
  "StaticPopup_Show",
  "UnitFrameManaBar_UpdateType",
  "UnitIsDead",
  "UnitIsGhost",
  "UnitPowerType",
  "hooksecurefunc",
  -- Blizzard data
  "PowerBarColor",
  -- Blizzard frames
  "PlayerLevelText",
  "TargetFrame",
  "PlayerFrame",
}

local _, ns = ...

-- Restores the Classic look to Blizzard's PlayerFrame in place. Blizzard's own code
-- keeps driving values, portraits and region visibility; this file changes only what
-- those regions are made of and where they sit.
--
-- Every number below comes from the Anniversary client's own layout, read 2026-09-16
-- from github.com/Gethe/wow-ui-source:
--   Classic  branch classic_anniversary, Interface/AddOns/Blizzard_UnitFrame/Classic/
--   Modern   branch live, Interface/AddOns/Blizzard_UnitFrame/Mainline/
-- Citations below name the file and line in those two directories.

local CLASSIC_BORDER = [[Interface\TargetingFrame\UI-TargetingFrame]]
local CLASSIC_BAR_FILL = [[Interface\TargetingFrame\UI-StatusBar]]

-- Classic/PlayerFrame.xml:54. Shared so the two border textures cannot drift apart.
local CLASSIC_BORDER_TEXCOORD = { 0.85546875, 0.1015625, 0.0625, 0.6640625 }
local CLASSIC_BORDER_SIZE = { 193, 77 }

local CONTAINER = "PlayerFrame.PlayerFrameContainer"
local CONTENT_MAIN = "PlayerFrame.PlayerFrameContent.PlayerFrameContentMain"
local CONTEXTUAL = "PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual"
local HEALTH_BARS = CONTENT_MAIN .. ".HealthBarsContainer"
local MANA_BAR = CONTENT_MAIN .. ".ManaBarArea.ManaBar"

-- One entry per region, applied in order.
--   path           key path from _G, resolved at apply time so a region Blizzard
--                  renames skips its own entry instead of erroring
--   texture        Texture:SetTexture
--   barTexture     StatusBar:SetStatusBarTexture
--   barColor       StatusBar:SetStatusBarColor, r g b
--   justifyH       FontString:SetJustifyH
--   texCoord       left, right, top, bottom
--   blendMode      Texture:SetBlendMode
--   size           width, height
--   point          anchored to PlayerFrame, the rect every Classic anchor is
--                  measured from
--   hitRectInsets  left, right, top, bottom
--   hide           a Modern-only region, or a mask the Classic art does not use
local spec = {
  -- Frame: Classic/PlayerFrame.xml:16.
  {
    path = "PlayerFrame",
    hitRectInsets = { 21, 19, 12, 15 },
  },

  -- Border: Classic/PlayerFrame.xml:54 (PlayerFrameTexture). Blizzard swaps
  -- AlternatePowerFrameTexture in for FrameTexture while a class resource is up
  -- (Mainline/PlayerFrame.lua:676-677), so both wear the Classic border and Blizzard
  -- keeps deciding which one shows.
  {
    path = CONTAINER .. ".FrameTexture",
    texture = CLASSIC_BORDER,
    texCoord = CLASSIC_BORDER_TEXCOORD,
    size = CLASSIC_BORDER_SIZE,
    point = { point = "CENTER" },
  },
  {
    path = CONTAINER .. ".AlternatePowerFrameTexture",
    texture = CLASSIC_BORDER,
    texCoord = CLASSIC_BORDER_TEXCOORD,
    size = CLASSIC_BORDER_SIZE,
    point = { point = "CENTER" },
  },

  -- Portrait: Classic/PlayerFrame.xml:36. Classic relies on SetPortraitTexture's own
  -- circular clip, which Blizzard disables through a field on the PlayerFrame table.
  -- Writing that field from addon code taints it, and UnitFrame_Update reads it right
  -- before the health bar update in the same call, which taints the health bar's
  -- stored value and makes its OnUpdate throw on secrets (see ADR 0002). So the
  -- Modern mask region stays and takes the Classic circular mask file instead.
  {
    path = CONTAINER .. ".PlayerPortrait",
    size = { 64, 64 },
    point = { point = "TOPLEFT", x = 24, y = -16 },
  },
  {
    path = CONTAINER .. ".PlayerPortraitMask",
    texture = [[Interface\CharacterFrame\TempPortraitAlphaMask]],
    size = { 64, 64 },
    point = { point = "TOPLEFT", x = 24, y = -16 },
  },

  -- Health bar: Classic/PlayerFrame.xml:280, matching Classic PlayerFrame_ToPlayerArt
  -- (Classic/PlayerFrame.lua:395-396). Modern splits the bar from the container that
  -- carries its anchor and its text, so both take the Classic geometry.
  {
    path = HEALTH_BARS,
    size = { 119, 12 },
    point = { point = "TOPLEFT", x = 90, y = -45 },
  },
  -- Modern pre-colors the health atlas and sets lockColor on the bar, so the Classic
  -- green that UnitFrameHealthBar_Update would normally apply has to come from here.
  {
    path = HEALTH_BARS .. ".HealthBar",
    barTexture = CLASSIC_BAR_FILL,
    barColor = { 0, 1, 0 },
    size = { 119, 12 },
  },
  {
    path = HEALTH_BARS .. ".HealthBarMask",
    hide = true,
  },

  -- Heal prediction and absorb sub-bars: Classic/PlayerFrame.xml:6, the fillTexture
  -- every PlayerFrameBarSegmentTemplate segment inherits.
  { path = HEALTH_BARS .. ".HealthBar.MyHealPredictionBar.Fill", texture = CLASSIC_BAR_FILL },
  { path = HEALTH_BARS .. ".HealthBar.OtherHealPredictionBar.Fill", texture = CLASSIC_BAR_FILL },
  { path = HEALTH_BARS .. ".HealthBar.HealAbsorbBar.Fill", texture = CLASSIC_BAR_FILL },
  { path = HEALTH_BARS .. ".HealthBar.TotalAbsorbBar.Fill", texture = CLASSIC_BAR_FILL },

  -- Mana bar: Classic/PlayerFrame.xml:306, matching Classic PlayerFrame_ToPlayerArt
  -- (Classic/PlayerFrame.lua:397-398).
  {
    path = MANA_BAR,
    barTexture = CLASSIC_BAR_FILL,
    size = { 119, 12 },
    point = { point = "TOPLEFT", x = 90, y = -56 },
  },
  {
    path = MANA_BAR .. ".ManaBarMask",
    hide = true,
  },

  -- Name and level: Classic/PlayerFrame.xml:67 and :74. Blizzard re-anchors both at
  -- runtime, which is why PlayerFrame_UpdatePlayerNameTextAnchor is hooked.
  {
    path = "PlayerName",
    -- Classic/PlayerFrame.xml:67 sets no justifyH and so takes the CENTER default,
    -- where Modern sets LEFT. Without this the name sits at the left edge of its box
    -- instead of centred on the anchor. PlayerLevelText is RIGHT on both, so it is
    -- left alone.
    justifyH = "CENTER",
    size = { 100, 12 },
    point = { point = "CENTER", x = 34, y = 15 },
  },
  {
    path = "PlayerLevelText",
    point = { point = "CENTER", relativePoint = "BOTTOMLEFT", x = 35.25, y = 30 },
  },

  -- Status glow: Classic/PlayerFrame.xml:117 (PlayerStatusTexture). Blizzard pulses
  -- this region's alpha while resting or in combat on both branches, so only its art,
  -- shape and blend change. ToPlayerArt re-sets the Modern atlas and anchor
  -- (Mainline/PlayerFrame.lua), which the hooks below undo.
  {
    path = CONTENT_MAIN .. ".StatusTexture",
    texture = [[Interface\CharacterFrame\UI-Player-Status]],
    texCoord = { 0, 0.74609375, 0, 0.53125 },
    blendMode = "ADD",
    size = { 190, 66 },
    point = { point = "TOPLEFT", x = 19, y = -12 },
  },

  -- Modern-only regions with no Classic counterpart. Blizzard re-shows both from
  -- PlayerFrame_UpdateStatus and PlayerFrame_UpdateRolesAssigned, so the hooks below
  -- hide them again.
  { path = CONTEXTUAL .. ".PlayerPortraitCornerIcon", hide = true },
  { path = CONTEXTUAL .. ".RoleIcon", hide = true },
}

local function ResolveRegion(path)
  local region = _G
  for key in string.gmatch(path, "[^.]+") do
    region = region[key]
    if region == nil then
      return nil
    end
  end
  return region
end

local function ApplyEntry(region, entry)
  if entry.texture then
    region:SetTexture(entry.texture)
  end
  if entry.texCoord then
    -- After SetTexture, so the file's own coords do not survive.
    local coord = entry.texCoord
    region:SetTexCoord(coord[1], coord[2], coord[3], coord[4])
  end
  if entry.blendMode then
    region:SetBlendMode(entry.blendMode)
  end
  if entry.barTexture then
    region:SetStatusBarTexture(entry.barTexture)
  end
  if entry.barColor then
    local color = entry.barColor
    region:SetStatusBarColor(color[1], color[2], color[3], 1)
  end
  if entry.justifyH then
    region:SetJustifyH(entry.justifyH)
  end
  if entry.size then
    region:SetSize(entry.size[1], entry.size[2])
  end
  if entry.point then
    -- Cleared first because the Modern anchor is often a different point than the
    -- Classic one, and SetPoint would leave both in place.
    local anchor = entry.point
    region:ClearAllPoints()
    region:SetPoint(anchor.point, PlayerFrame, anchor.relativePoint or anchor.point, anchor.x or 0, anchor.y or 0)
  end
  if entry.hitRectInsets then
    local insets = entry.hitRectInsets
    region:SetHitRectInsets(insets[1], insets[2], insets[3], insets[4])
  end
  if entry.hide then
    region:Hide()
  end
end

local function StatusBarTexture(bar)
  return bar and bar:GetStatusBarTexture()
end

local function RemoveMask(texture, mask)
  if texture and mask then
    texture:RemoveMaskTexture(mask)
  end
end

-- PlayerFrame_OnLoad clips the bar fills to the Modern silhouettes
-- (Mainline/PlayerFrame.lua:29-47). The Classic bars are plain rectangles, so the
-- masks come off the same objects Blizzard put them on. The MaskTexture regions
-- themselves are hidden by the spec table, which covers what the XML masks.
local function UnmaskBars()
  local healthBars = ResolveRegion(HEALTH_BARS)
  if healthBars then
    local mask = healthBars.HealthBarMask
    RemoveMask(StatusBarTexture(healthBars.HealthBar), mask)
    RemoveMask(StatusBarTexture(healthBars.PlayerFrameHealthBarAnimatedLoss), mask)
    RemoveMask(StatusBarTexture(healthBars.PlayerFrameTempMaxHealthLoss), mask)
  end

  local manaBar = ResolveRegion(MANA_BAR)
  if manaBar then
    local mask = manaBar.ManaBarMask
    RemoveMask(StatusBarTexture(manaBar), mask)

    -- BuilderSpender:AddMaskTexture fans the mask out to three textures and ships no
    -- matching remove (Mainline/BuilderSpenderFrame.lua:23-27), so each one is
    -- unmasked here rather than through the frame.
    local feedback = manaBar.FeedbackFrame
    if feedback then
      RemoveMask(feedback.BarTexture, mask)
      RemoveMask(feedback.GainGlowTexture, mask)
      RemoveMask(feedback.LossGlowTexture, mask)
    end
  end
end

-- The Classic mana bar is one grayscale file tinted per power type. Blizzard's
-- UnitFrameManaBar_UpdateType (Mainline/UnitFrame.lua:490) swaps a Modern atlas back
-- in on every power update, so the Classic look is re-applied after it. This mirrors
-- the non-atlas branch of the Classic function (Classic/UnitFrame.lua:463).
--
-- Deliberately outside the combat gate: it sets a texture and a color, never a size,
-- anchor or visibility, so it carries no lockdown risk. Gating it would leave a druid
-- who shifts form mid-fight wearing the Modern fill for the rest of the fight.
--
-- Runs for every unit frame's mana bar, so it returns unless this is the player's.
local function RestoreClassicManaFill(manaBar)
  if not manaBar or manaBar ~= ResolveRegion(MANA_BAR) then
    return
  end

  -- Blizzard sets powerToken here only when the power type changes, which always
  -- happens before its first return, so by hook time the field is current.
  local powerToken = manaBar.powerToken or select(2, UnitPowerType("player"))

  -- STAGGER and SOUL_FRAGMENTS nest their colors a level down and carry no r of their
  -- own, so an entry without one falls back the way Blizzard's own lookup does.
  local color = PowerBarColor[powerToken]
  if not (color and color.r) then
    color = PowerBarColor["MANA"]
  end

  manaBar:SetStatusBarTexture(CLASSIC_BAR_FILL)
  if UnitIsDead("player") or UnitIsGhost("player") then
    manaBar:SetStatusBarColor(0.6, 0.6, 0.6, 0.5)
  else
    manaBar:SetStatusBarColor(color.r, color.g, color.b, 1)
  end

  -- Blizzard fades and desaturates the fill for a dead player. Classic says that with
  -- color alone, so the texture's own state goes back to neutral.
  local fill = manaBar:GetStatusBarTexture()
  if fill then
    fill:SetDesaturated(false)
    fill:SetAlpha(1)
  end
end

local applyPending = false

-- Sizing, anchoring and hit rects on a protected frame are restricted in combat, so
-- every path into the Classic look waits for the lockdown to lift.
local function Apply()
  if InCombatLockdown() then
    applyPending = true
    return
  end

  applyPending = false
  for _, entry in ipairs(spec) do
    local region = ResolveRegion(entry.path)
    if region then
      ApplyEntry(region, entry)
    end
  end
  -- PlayerFrame_UpdateRolesAssigned hides the level to make room for the role icon
  -- (Mainline/PlayerFrame.lua:440-441), and the spec table hides that icon. Classic
  -- has no role icon and always shows the level, except in a vehicle, where Blizzard
  -- hides it on purpose (Mainline/PlayerFrame.lua:647).
  if PlayerFrame.state ~= "vehicle" then
    PlayerLevelText:Show()
  end

  UnmaskBars()
  RestoreClassicManaFill(ResolveRegion(MANA_BAR))
end

-- Blizzard re-applies the Modern art from each of these. Looked up by name so a
-- function Blizzard renames drops its hook instead of erroring at load.
local ART_FUNCTIONS = {
  "PlayerFrame_ToPlayerArt",
  "PlayerFrame_ToVehicleArt",
  "PlayerFrame_UpdateArt",
  "PlayerFrame_UpdateStatus",
  "PlayerFrame_UpdateRolesAssigned",
  "PlayerFrame_UpdatePlayerNameTextAnchor",
}

local function Restore()
  Apply()

  local combatWatcher = CreateFrame("Frame")
  combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
  combatWatcher:SetScript("OnEvent", function()
    if applyPending then
      Apply()
    end
  end)

  -- Hooked on its own rather than through ART_FUNCTIONS: it fires on every power tick,
  -- where the full Apply would be far too much work, and it must not wait for combat.
  if type(UnitFrameManaBar_UpdateType) == "function" then
    hooksecurefunc("UnitFrameManaBar_UpdateType", RestoreClassicManaFill)
  end

  for _, name in ipairs(ART_FUNCTIONS) do
    if type(_G[name]) == "function" then
      hooksecurefunc(name, Apply)
    end
  end
end

ns.RegisterElement("PlayerFrame", Restore)

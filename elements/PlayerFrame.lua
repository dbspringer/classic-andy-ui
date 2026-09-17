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
-- Shared with the engine, which tints it for the mana bar (Restore.lua).
local CLASSIC_BAR_FILL = ns.CLASSIC_BAR_FILL
local CLASSIC_STATE_ICON = [[Interface\CharacterFrame\UI-StateIcon]]
local CLASSIC_LEADER_ICON = [[Interface\GroupFrame\UI-Group-LeaderIcon]]
local CLASSIC_GROUP_INDICATOR = [[Interface\CharacterFrame\UI-CharacterFrame-GroupIndicator]]

-- Classic/PlayerFrame.lua:132 and :147 build the PvP banner's file by appending either
-- FFA or the player's faction group to this prefix.
local CLASSIC_PVP_ICON = [[Interface\TargetingFrame\UI-PVP-]]

-- Classic/PlayerFrame.xml:54. Shared so the two border textures cannot drift apart.
local CLASSIC_BORDER_TEXCOORD = { 0.85546875, 0.1015625, 0.0625, 0.6640625 }
local CLASSIC_BORDER_SIZE = { 193, 77 }

local CONTAINER = "PlayerFrame.PlayerFrameContainer"
local CONTENT_MAIN = "PlayerFrame.PlayerFrameContent.PlayerFrameContentMain"
local CONTEXTUAL = "PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual"
local HEALTH_BARS = CONTENT_MAIN .. ".HealthBarsContainer"
local MANA_BAR = CONTENT_MAIN .. ".ManaBarArea.ManaBar"
local GROUP_INDICATOR = CONTEXTUAL .. ".GroupIndicator"

local ResolveRegion = ns.ResolveRegion

-- Modern declares the group indicator's middle piece with no name and no parentKey
-- (Mainline/PlayerFrame.xml:436-441), so there is no key path to it and it has to be
-- picked out of the frame's own regions: the one Texture that is neither keyed end.
-- The FontString beside them is skipped by type.
local function ResolveGroupIndicatorMiddle()
  local indicator = ResolveRegion(GROUP_INDICATOR)
  if not indicator then
    return nil
  end

  for _, region in ipairs({ indicator:GetRegions() }) do
    if region:GetObjectType() == "Texture"
      and region ~= indicator.GroupIndicatorLeft
      and region ~= indicator.GroupIndicatorRight then
      return region
    end
  end
  return nil
end

-- One entry per region, applied in order. Restore.lua documents every field.
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
--
  -- OVERLAY sublevel 0 is what puts the border over the bar fills. The bars come down
  -- to the border's own frame level below, and at one level the draw layer decides, so
  -- fills on BACKGROUND and ARTWORK end up under the slot edges the way Classic had
  -- them. The bar text stays above: Modern keeps it on OVERLAY sublevel 1
  -- (Mainline/PlayerFrame.xml:199, :261), which is also where Classic's text sat
  -- relative to the border.
  {
    path = CONTAINER .. ".FrameTexture",
    texture = CLASSIC_BORDER,
    texCoord = CLASSIC_BORDER_TEXCOORD,
    drawLayer = { "OVERLAY", 0 },
    size = CLASSIC_BORDER_SIZE,
    point = { point = "CENTER" },
  },
  {
    path = CONTAINER .. ".AlternatePowerFrameTexture",
    texture = CLASSIC_BORDER,
    texCoord = CLASSIC_BORDER_TEXCOORD,
    drawLayer = { "OVERLAY", 0 },
    size = CLASSIC_BORDER_SIZE,
    point = { point = "CENTER" },
  },
  -- The vehicle border is still Modern art (a later PR), but it plays the same role, so
  -- it takes the same place in the stack (Mainline/PlayerFrame.xml:44).
  { path = CONTAINER .. ".VehicleFrameTexture", drawLayer = { "OVERLAY", 0 } },

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
  --
  -- Classic stacks bars under the border and text over it: its health and mana bars are
  -- direct children of PlayerFrame (Classic/PlayerFrame.xml:280, :306) while the border
  -- lives a level up in rightFrame.textFrame (:47, :54). Modern inverts that, parking
  -- the bars under PlayerFrameContentMain two levels up while the border stays one
  -- (Mainline/PlayerFrame.xml:24, :71, :108). The bars go level with the border's
  -- container, where the OVERLAY border draws above their BACKGROUND and ARTWORK
  -- fills, and stay one above PlayerFrame so they still win the mouse for the value
  -- text on hover. At PlayerFrame's own level the parent took the mouse instead.
  {
    path = HEALTH_BARS,
    frameLevel = 1,
    size = { 119, 12 },
    point = { point = "TOPLEFT", x = 90, y = -45 },
  },
  -- Modern pre-colors the health atlas and sets lockColor on the bar, so the Classic
  -- green that UnitFrameHealthBar_Update would normally apply has to come from here.
  {
    path = HEALTH_BARS .. ".HealthBar",
    barTexture = CLASSIC_BAR_FILL,
    barColor = { 0, 1, 0 },
    frameLevel = 1,
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
  -- Each segment already carries useParentLevel through StatusBarOverlaySegmentTemplate
  -- (Shared/UnitFrame.xml:3, :8, :13, :18 into Shared/StatusBarOverlaySegment.xml:3), so
  -- these are belt and braces: they cost nothing if the flag already moved the frame,
  -- and they are the whole fix if it did not.
  { path = HEALTH_BARS .. ".HealthBar.MyHealPredictionBar", frameLevel = 1 },
  { path = HEALTH_BARS .. ".HealthBar.OtherHealPredictionBar", frameLevel = 1 },
  { path = HEALTH_BARS .. ".HealthBar.HealAbsorbBar", frameLevel = 1 },
  { path = HEALTH_BARS .. ".HealthBar.TotalAbsorbBar", frameLevel = 1 },

  -- Mana bar: Classic/PlayerFrame.xml:306, matching Classic PlayerFrame_ToPlayerArt
  -- (Classic/PlayerFrame.lua:397-398).
  { path = CONTENT_MAIN .. ".ManaBarArea", frameLevel = 1 },
  {
    path = MANA_BAR,
    barTexture = CLASSIC_BAR_FILL,
    frameLevel = 1,
    size = { 119, 12 },
    point = { point = "TOPLEFT", x = 90, y = -56 },
  },
  -- ManaCostPredictionBar is another overlay segment, so it follows its parent the way
  -- the health ones do. FullPowerFrame is the one bar frame with no useParentLevel
  -- anywhere in its chain (Mainline/PlayerFrame.xml:251 into
  -- Mainline/BuilderSpenderFrame.xml:20), so it needs this entry to come down at all.
  { path = MANA_BAR .. ".ManaCostPredictionBar", frameLevel = 1 },
  { path = MANA_BAR .. ".FullPowerFrame", frameLevel = 1 },
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
    point = { point = "CENTER", relativePoint = "BOTTOMLEFT", x = 37, y = 30 },
  },

  -- Status glow: Classic/PlayerFrame.xml:117 (PlayerStatusTexture). Blizzard pulses
  -- this region's alpha while resting or in combat on both branches, so only its art,
  -- shape and blend change. ToPlayerArt re-sets the Modern atlas and anchor
  -- (Mainline/PlayerFrame.lua:694-695), which the hooks below undo.
  {
    path = CONTENT_MAIN .. ".StatusTexture",
    texture = [[Interface\CharacterFrame\UI-Player-Status]],
    texCoord = { 0, 0.74609375, 0, 0.53125 },
    blendMode = "ADD",
    -- Classic draws the glow on ARTWORK, under the PvP banner and the icons. Modern
    -- puts it on OVERLAY, where its additive blend washes over the banner.
    drawLayer = { "ARTWORK", 0 },
    size = { 190, 66 },
    point = { point = "TOPLEFT", x = 19, y = -12 },
  },

  -- Full-frame combat flash: Classic/PlayerFrame.xml:20 (PlayerFrameFlash). Blizzard
  -- decides when it flashes; ToPlayerArt and ToVehicleArt re-set its atlas and its
  -- anchor every time (Mainline/PlayerFrame.lua:681-691 and :587-589), which the hooks
  -- below undo.
  {
    path = CONTAINER .. ".FrameFlash",
    texture = [[Interface\TargetingFrame\UI-TargetingFrame-Flash]],
    -- Classic/PlayerFrame.xml:20 puts the flash on BACKGROUND of PlayerFrame, under the
    -- portrait, which Classic draws on ARTWORK (:36). Modern's portrait is BACKGROUND
    -- sublevel 1 in this same container, so sublevel 0 keeps the flash beneath it.
    drawLayer = { "BACKGROUND", 0 },
    -- Left is greater than right: Classic mirrors this file horizontally.
    texCoord = { 0.9453125, 0, 0, 0.181640625 },
    size = { 242, 93 },
    point = { point = "TOPLEFT", x = -3, y = -4 },
  },

  -- Anchors for the level, the bubble, the swords, their glows and the backing sit
  -- one to three pixels off the Classic XML values (level 35.25,30; bubble and rest
  -- glow 19.5,-52; swords and attack glow 20.5,-52; backing 19,-54). Tuned by eye
  -- against the Anniversary client on 2026-09-16, because at those values the
  -- medallion in the border art read as off-centre on Midnight even though every
  -- measured rect matched Classic. Each glow keeps Classic's alignment to its icon.
  -- Rest bubble: Classic/PlayerFrame.xml:155 (PlayerRestIcon), a static bubble that
  -- Modern replaced with a 42-frame flipbook inside PlayerRestLoop
  -- (Mainline/PlayerFrame.xml:380-397). The flipbook's own texture is hidden and a
  -- mirror carries the Classic art.
  --
  -- The RestTexture is hidden, not the PlayerRestLoop frame, because that frame is
  -- what the mirror follows: hiding it would take the mirror down with it. Blizzard
  -- shows and hides the frame from PlayerFrame_UpdatePlayerRestLoop
  -- (Mainline/PlayerFrame.lua:512) and never re-shows the texture.
  { path = CONTEXTUAL .. ".PlayerRestLoop.RestTexture", hide = true },
  {
    mirror = "RestIcon",
    follows = CONTEXTUAL .. ".PlayerRestLoop",
    drawLayer = { "OVERLAY", 0 },
    texture = CLASSIC_STATE_ICON,
    texCoord = { 0, 0.5, 0, 0.421875 },
    size = { 31, 33 },
    point = { point = "TOPLEFT", x = 21, y = -53 },
  },
  -- Rest glow: Classic/PlayerFrame.xml:200 (PlayerRestGlow), the additive halo that
  -- fills the border's medallion around the bubble. Its frame is anchored TOPLEFT to
  -- PlayerRestIcon at 0,0 (:196) and the texture sits at 0,0 inside it (:203), so from
  -- PlayerFrame it lands on the bubble's own 19.5,-52.
  --
  -- Sublevel 1 puts it over the bubble, not under. The glow's own frame raises itself
  -- three levels above the one holding the icons (:219), so Classic drew it on top of
  -- both the bubble and the swords, and an ADD blend under an opaque bubble would show
  -- almost nothing.
  {
    mirror = "RestGlow",
    follows = CONTEXTUAL .. ".PlayerRestLoop",
    drawLayer = { "OVERLAY", 1 },
    texture = CLASSIC_STATE_ICON,
    texCoord = { 0, 0.5, 0.5, 1.0 },
    blendMode = "ADD",
    size = { 32, 32 },
    point = { point = "TOPLEFT", x = 21, y = -53 },
  },

  -- Combat backing and swords: Classic/PlayerFrame.xml:124 (PlayerAttackBackground) and
  -- :162 (PlayerAttackIcon). The backing has to be a mirror because Modern has no
  -- counterpart, and the swords follow it onto the host: the host outranks the frame
  -- AttackIcon lives on, so a retextured AttackIcon would draw over its own backing.
  -- On the host, ARTWORK under OVERLAY is the order Classic drew the two in.
  --
  -- AttackIcon is turned transparent rather than hidden. Blizzard shows and hides it
  -- from PlayerFrame_UpdateStatus (Mainline/PlayerFrame.lua:488, :495, :500, :506) and
  -- that is the visibility both mirrors follow, so hiding it would take them with it.
  { path = CONTEXTUAL .. ".AttackIcon", alpha = 0 },
  {
    mirror = "AttackBackground",
    follows = CONTEXTUAL .. ".AttackIcon",
    drawLayer = { "ARTWORK", 0 },
    texture = [[Interface\TargetingFrame\UI-TargetingFrame-AttackBackground]],
    size = { 32, 32 },
    point = { point = "TOPLEFT", x = 21, y = -54 },
  },
  -- Classic/PlayerFrame.xml:162 anchors PlayerAttackIcon's TOPLEFT to PlayerRestIcon's
  -- TOPLEFT at 1,0. PlayerRestIcon sits at 19.5,-52 from PlayerFrame's TOPLEFT, so the
  -- same spot measured from PlayerFrame is 20.5,-52. It shares OVERLAY with the rest
  -- bubble, which needs no tie-break: Blizzard never shows the two at once
  -- (Mainline/PlayerFrame.lua:485-509).
  {
    mirror = "AttackSwords",
    follows = CONTEXTUAL .. ".AttackIcon",
    drawLayer = { "OVERLAY", 0 },
    texture = CLASSIC_STATE_ICON,
    texCoord = { 0.5, 1.0, 0, 0.484375 },
    size = { 32, 32 },
    point = { point = "TOPLEFT", x = 22.5, y = -55 },
  },
  -- Combat glow: Classic/PlayerFrame.xml:207 (PlayerAttackGlow), the same halo tinted
  -- red, at 1,0 inside the glow frame (:210) and so at 20.5,-52 from PlayerFrame. Over
  -- the swords for the reason the rest glow is over the bubble.
  --
  -- Classic hides the glow while the player is only on a hate list and out of combat
  -- (Classic/PlayerFrame.lua:491-495), where it still shows the swords. Following
  -- AttackIcon cannot tell those two apart, so this glow also shows there. Known gap.
  {
    mirror = "AttackGlow",
    follows = CONTEXTUAL .. ".AttackIcon",
    drawLayer = { "OVERLAY", 1 },
    texture = CLASSIC_STATE_ICON,
    texCoord = { 0.5, 1.0, 0.5, 1.0 },
    blendMode = "ADD",
    vertexColor = { 1, 0, 0 },
    size = { 32, 32 },
    point = { point = "TOPLEFT", x = 22.5, y = -55 },
  },

  -- PvP banner: Classic/PlayerFrame.xml:130 (PlayerPVPIcon). Which file it wears
  -- depends on faction and is set by RestoreClassicPvPIcon; only its shape is fixed
  -- here. The coords are restored explicitly because SetAtlas leaves the atlas's own
  -- coords on the region and SetTexture alone is not guaranteed to clear them.
  {
    path = CONTEXTUAL .. ".PVPIcon",
    texCoord = { 0, 1, 0, 1 },
    -- Classic/PlayerFrame.xml:86 declares the banner on ARTWORK after the status glow,
    -- so it draws over the glow. Sublevel 1 keeps that order on Modern's frames.
    drawLayer = { "ARTWORK", 1 },
    size = { 64, 64 },
    point = { point = "TOPLEFT", x = 2, y = -24 },
  },
  -- Honor prestige art postdates Classic. Blizzard shows these two in place of the PvP
  -- banner once the player has an honor reward (Mainline/PlayerFrame.lua:344-349), so
  -- they are hidden and PlayerFrame_UpdatePvPStatus is hooked to hide them again.
  { path = CONTEXTUAL .. ".PrestigePortrait", hide = true },
  { path = CONTEXTUAL .. ".PrestigeBadge", hide = true },

  -- Leader and guide: Classic/PlayerFrame.xml:143 (PlayerLeaderIcon). Classic has no
  -- guide icon and a guide leads the group, so both wear the Classic crown rather than
  -- one of them disappearing. Blizzard only shows and hides them
  -- (Mainline/PlayerFrame.lua:302-311), so their art is set once and stays.
  {
    path = CONTEXTUAL .. ".LeaderIcon",
    texture = CLASSIC_LEADER_ICON,
    size = { 16, 16 },
    point = { point = "TOPLEFT", x = 28, y = -14 },
  },
  {
    path = CONTEXTUAL .. ".GuideIcon",
    texture = CLASSIC_LEADER_ICON,
    size = { 16, 16 },
    point = { point = "TOPLEFT", x = 28, y = -14 },
  },

  -- Raid subgroup indicator: Classic/PlayerFrame.xml:323. Classic sits it above the
  -- portrait; Modern hangs it off the right of the frame and re-anchors it from
  -- ToPlayerArt and ToVehicleArt (Mainline/PlayerFrame.lua:753 and :645).
  --
  -- No size: PlayerFrame_UpdateGroupIndicator computes the width from its text on both
  -- branches with the same formula (Classic/PlayerFrame.lua:518,
  -- Mainline/PlayerFrame.lua:540), and the height is 16 on both. Setting the XML's
  -- pre-text default of 10 here would undo Blizzard's measurement.
  {
    path = GROUP_INDICATOR,
    point = { point = "BOTTOMLEFT", relativePoint = "TOPLEFT", x = 81, y = -24 },
  },
  -- All three pieces come off one file. Left and Right keep Modern's TOPLEFT and
  -- TOPRIGHT anchors, which are the anchors Classic used too, so only their file,
  -- coords, size and alpha change. Classic dims all three to 0.3 in the frame's OnLoad
  -- (Classic/PlayerFrame.xml:361-363), where Modern leaves them opaque.
  {
    path = GROUP_INDICATOR .. ".GroupIndicatorLeft",
    texture = CLASSIC_GROUP_INDICATOR,
    texCoord = { 0, 0.1875, 0, 1 },
    alpha = 0.3,
    size = { 24, 16 },
  },
  {
    path = GROUP_INDICATOR .. ".GroupIndicatorRight",
    texture = CLASSIC_GROUP_INDICATOR,
    texCoord = { 0.53125, 0.71875, 0, 1 },
    alpha = 0.3,
    size = { 24, 16 },
  },
  -- The middle piece stretches between the two ends, so Classic gives it no width of
  -- its own and a height of 16 (Classic/PlayerFrame.xml:345-349). A width of zero is
  -- how both branches say "let the anchors decide", which is what Modern's atlas size
  -- would otherwise override.
  {
    resolve = ResolveGroupIndicatorMiddle,
    texture = CLASSIC_GROUP_INDICATOR,
    texCoord = { 0.1875, 0.53125, 0, 1 },
    alpha = 0.3,
    size = { 0, 16 },
  },

  -- Playtime warning: Classic/PlayerFrame.xml:230 (PlayerPlayTimeIcon). Blizzard
  -- re-sets this atlas from PlayerFrame_UpdatePlaytime (Mainline/PlayerFrame.lua:553),
  -- which the hooks below undo. Classic swapped in UI-Player-PlayTimeUnhealthy for the
  -- stricter state (Classic/PlayerFrame.lua:533); that variant is not restored, so both
  -- states show the tired icon.
  {
    path = CONTEXTUAL .. ".PlayerPlayTime.PlayTimeIcon",
    texture = [[Interface\CharacterFrame\UI-Player-PlayTimeTired]],
  },

  -- Modern-only regions with no Classic counterpart. Blizzard re-shows both from
  -- PlayerFrame_UpdateStatus and PlayerFrame_UpdateRolesAssigned, so the hooks below
  -- hide them again.
  { path = CONTEXTUAL .. ".PlayerPortraitCornerIcon", hide = true },
  { path = CONTEXTUAL .. ".RoleIcon", hide = true },
}

-- Classic pulses the glow with the same alpha it gives the status texture, every frame
-- while that texture shows (Classic/PlayerFrame.lua:440-441, PlayerFrame_OnUpdate).
-- Modern's PlayerFrame_OnUpdate makes that same call on its own StatusTexture
-- (Mainline/PlayerFrame.lua:214), so following the one call carries the pulse across.
-- Blizzard is already making it every frame the glow is up, so this adds one Lua call
-- per frame and nothing else.
--
-- Classic showed its glow only in the resting and combat branches of
-- PlayerFrame_UpdateStatus (Classic/PlayerFrame.lua:478-489). Following PlayerRestLoop
-- and AttackIcon gives the same visibility, apart from the hate-list case noted on the
-- combat glow above.
local GLOW_MIRRORS = { "RestGlow", "AttackGlow" }

local function FollowStatusGlowAlpha(restorer)
  local statusTexture = ResolveRegion(CONTENT_MAIN .. ".StatusTexture")
  if not statusTexture then
    return
  end

  local function Pulse(_, alpha)
    for _, name in ipairs(GLOW_MIRRORS) do
      local glow = restorer:Mirror(name)
      if glow then
        glow:SetAlpha(alpha)
      end
    end
  end

  hooksecurefunc(statusTexture, "SetAlpha", Pulse)
  -- The pulse only runs while the status texture shows, so the glows start from
  -- whatever alpha it is already carrying.
  Pulse(statusTexture, statusTexture:GetAlpha())
end

local StatusBarTexture = ns.StatusBarTexture
local RemoveMask = ns.RemoveMask

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

-- Blizzard sets the Modern PvP atlas from PlayerFrame_UpdatePvPStatus
-- (Mainline/PlayerFrame.lua:353, :386 and :392). This is Classic's whole banner
-- decision instead (Classic/PlayerFrame.lua:125-161): free for all wins, else a
-- faction group plus a PvP flag, else nothing. Classic has no mercenary-mode faction
-- swap, so neither does this.
--
-- This is the one region whose visibility the addon decides rather than Blizzard.
-- Modern hands the flagged-with-an-honor-reward case to PrestigePortrait and hides the
-- banner (Mainline/PlayerFrame.lua:344-349); the spec table hides the prestige art,
-- which would leave a flagged player wearing no banner at all. Reading the same two
-- unit states Classic read is what puts it back. Both are the player's own unit, so
-- neither returns a secret value.
--
-- Ungated, like the mana fill: the banner is a Texture, and the combat gate holds back
-- a Frame only. A player who flags mid-fight gets the banner without waiting for the
-- fight to end.
--
-- Called from AfterApply rather than from a hook of its own, because
-- PlayerFrame_UpdatePvPStatus is already in ART_FUNCTIONS and AfterApply is where the
-- mana fill is restored from too.
local function RestoreClassicPvPIcon()
  local icon = ResolveRegion(CONTEXTUAL .. ".PVPIcon")
  if not icon then
    return
  end

  local shown = true
  if UnitIsPVPFreeForAll("player") then
    icon:SetTexture(CLASSIC_PVP_ICON .. "FFA")
  else
    local factionGroup = UnitFactionGroup("player")
    if factionGroup and factionGroup ~= "Neutral" and UnitIsPVP("player") then
      icon:SetTexture(CLASSIC_PVP_ICON .. factionGroup)
    else
      shown = false
    end
  end

  icon:SetShown(shown)
end

-- Blizzard re-applies the Modern art from each of these. Looked up by name so a
-- function Blizzard renames drops its hook instead of erroring at load.
--
-- Three neighbours are deliberately absent, each checked against the live source:
-- PlayerFrame_UpdatePartyLeader only shows and hides the two group icons (:302-311),
-- PlayerFrame_UpdatePlayerRestLoop only shows and hides the flipbook frame and its
-- animation (:512-522), and PlayerFrame_UpdateGroupIndicator only sets a width it
-- measures from its own text (:540), which is what Classic did too. None of them
-- re-sets an atlas or an anchor, so none of them needs a pass.
local ART_FUNCTIONS = {
  "PlayerFrame_ToPlayerArt",
  "PlayerFrame_ToVehicleArt",
  "PlayerFrame_UpdateArt",
  "PlayerFrame_UpdateStatus",
  "PlayerFrame_UpdateRolesAssigned",
  "PlayerFrame_UpdatePlayerNameTextAnchor",
  -- Re-sets the PvP atlas at its own size and re-shows the prestige portrait and badge
  -- (Mainline/PlayerFrame.lua:344-349, :353, :386-392).
  "PlayerFrame_UpdatePvPStatus",
  -- Re-sets the playtime atlas at its own size (Mainline/PlayerFrame.lua:553, :557).
  "PlayerFrame_UpdatePlaytime",
}

local function Restore()
  local restorer = ns.NewRestorer(PlayerFrame)

  -- PlayerFrame_UpdateRolesAssigned hides the level to make room for the role icon
  -- (Mainline/PlayerFrame.lua:440-441), and the spec table hides that icon. Classic
  -- has no role icon and always shows the level, except in a vehicle, where Blizzard
  -- hides it on purpose (Mainline/PlayerFrame.lua:647). PlayerLevelText is a
  -- FontString, so the show sits outside the combat gate.
  local function AfterApply()
    if PlayerFrame.state ~= "vehicle" then
      PlayerLevelText:Show()
    end

    UnmaskBars()
    ns.RestoreManaFill(ResolveRegion(MANA_BAR))
    RestoreClassicPvPIcon()
  end

  -- Registered before the first pass, because AfterApply restores the fill and the
  -- engine passes over a bar it has not been handed a unit for.
  restorer:RegisterManaBar(ResolveRegion(MANA_BAR), "player")

  restorer:Apply(spec, AfterApply)
  restorer:WatchCombat()

  -- After the first Apply, so the glow mirrors it drives already exist.
  FollowStatusGlowAlpha(restorer)

  restorer:Hook(ART_FUNCTIONS, function()
    restorer:Apply(spec, AfterApply)
  end)
end

ns.RegisterElement("PlayerFrame", Restore)

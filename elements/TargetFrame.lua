local _, ns = ...

-- Restores the Classic look to Blizzard's TargetFrame in place, and to the
-- target-of-target frame hanging off it. Blizzard's own code keeps driving values,
-- portraits and region visibility; this file changes only what those regions are made
-- of and where they sit.
--
-- Every number below comes from the Anniversary client's own layout, read 2026-09-17
-- from github.com/Gethe/wow-ui-source:
--   Classic  branch classic_anniversary, Interface/AddOns/Blizzard_UnitFrame/Classic/
--   Modern   branch live, Interface/AddOns/Blizzard_UnitFrame/Mainline/
-- Citations below name the file and line in those two directories.
--
-- Everything is built against a frame and its global name rather than against
-- TargetFrame itself. FocusFrame inherits the same TargetFrameTemplate and so carries
-- the same region tree (Mainline/TargetFrame.xml:542, :565), which is what a focus
-- element would reuse. Only the target frame is wired up here.
--
-- No mirrors. Every Classic region on this frame has a Modern counterpart, with one
-- exception: Classic's black bar backing (Classic/TargetFrame.xml:161), 119x25 at
-- TOPRIGHT -89.5,-26. It sits entirely behind the opaque name plate and the top of the
-- health bar, so it shows nowhere in the reference screenshot, and the Classic border
-- art carries the recessed bar troughs on its own. So this element creates no mirror
-- host and needs no mirror level of its own.

local CLASSIC_BORDER = [[Interface\TargetingFrame\UI-TargetingFrame]]
local CLASSIC_TOT_BORDER = [[Interface\TargetingFrame\UI-TargetofTargetFrame]]
-- Shared with the engine, which tints it for the mana bars (Restore.lua).
local CLASSIC_BAR_FILL = ns.CLASSIC_BAR_FILL
local CLASSIC_PORTRAIT_MASK = [[Interface\CharacterFrame\TempPortraitAlphaMask]]
local CLASSIC_LEADER_ICON = [[Interface\GroupFrame\UI-Group-LeaderIcon]]
local CLASSIC_QUEST_ICON = [[Interface\TargetingFrame\PortraitQuestBadge]]
local CLASSIC_SKULL = [[Interface\TargetingFrame\UI-TargetingFrame-Skull]]

-- Classic/TargetFrame.lua:301 and :304 build the PvP banner's file by appending either
-- FFA or the unit's faction group to this prefix.
local CLASSIC_PVP_ICON = [[Interface\TargetingFrame\UI-PVP-]]

-- Classic/TargetFrame.xml:189-195. One geometry for all five classification files: the
-- XML comment there says the size, anchor and coords are chosen to hold the larger
-- Elite art, so the border never changes shape, only which file it reads.
local CLASSIC_BORDER_TEXCOORD = { 0.1015625, 1.0, 0.0078125, 0.78125 }
local CLASSIC_BORDER_SIZE = { 230, 99 }

-- Classic/TargetFrame.lua:28-34 (TARGET_FRAME_TEXTURES), plus the worldboss case that
-- CheckClassification folds into elite (Classic/TargetFrame.lua:342). Anything absent,
-- including a nil classification when there is no target, falls back to the normal
-- border below.
local CLASSIC_BORDERS = {
  minus = [[Interface\TargetingFrame\UI-TargetingFrame-Minus]],
  elite = [[Interface\TargetingFrame\UI-TargetingFrame-Elite]],
  worldboss = [[Interface\TargetingFrame\UI-TargetingFrame-Elite]],
  rareelite = [[Interface\TargetingFrame\UI-TargetingFrame-Rare-Elite]],
  rare = [[Interface\TargetingFrame\UI-TargetingFrame-Rare]],
}

-- The threat flash, which Modern calls Flash and hands to UnitFrame_UpdateThreatIndicator
-- as self.threatIndicator (Mainline/TargetFrame.lua:35). Classic gives it three shapes
-- (Classic/TargetFrame.lua:362-385), anchored TOPLEFT from the frame at the
-- threatAnchorX/Y and threatEliteAnchorX/Y key values (Classic/TargetFrame.xml:142-145).
-- Modern's frame carries no such key values, so the numbers are constants here.
local CLASSIC_FLASH = [[Interface\TargetingFrame\UI-TargetingFrame-Flash]]
local FLASH_NORMAL = {
  texture = CLASSIC_FLASH,
  texCoord = { 0, 0.9453125, 0, 0.181640625 },
  size = { 242, 93 },
  x = -6,
  y = -3,
}
local FLASH_ELITE = {
  texture = CLASSIC_FLASH,
  texCoord = { 0, 0.9453125, 0.181640625, 0.400390625 },
  size = { 242, 112 },
  x = -4,
  y = 6,
}
local FLASH_MINUS = {
  texture = [[Interface\TargetingFrame\UI-TargetingFrame-Minus-Flash]],
  texCoord = { 0, 1, 0, 1 },
  size = { 256, 128 },
  x = -6,
  y = -3,
}

-- Classic reaches the elite flash through forceNormalTexture, which stays unset for
-- every classification that takes a dragon border: elite, worldboss, rareelite and
-- rare alike (Classic/TargetFrame.lua:342-351 into :376-385). Rare included, which is
-- where ClassicFrames differs -- it gives rare the 242x93 shape
-- (ClassicFrames/skins/unitframes/TargetFrame.lua:232-236). Classic's own code wins.
local CLASSIC_FLASHES = {
  minus = FLASH_MINUS,
  elite = FLASH_ELITE,
  worldboss = FLASH_ELITE,
  rareelite = FLASH_ELITE,
  rare = FLASH_ELITE,
}

-- Blizzard's Modern CheckFaction picks the PvP banner's atlas from the unit's faction
-- and PvP state (Mainline/TargetFrame.lua:328, :336, :343, :352, :354). Reading the
-- atlas it just set is how this file learns the faction without calling a unit API of
-- its own: UnitIsPVP is flagged SecretWhenUnitIdentityRestricted in the client's own
-- API documentation, so on a restricted map it can hand addon code a secret value, and
-- a secret reaching SetShown is the ADR 0002 failure. The player frame can read the
-- unit directly because the player's own unit is never restricted; a target can be.
local CLASSIC_PVP_FACTION = {
  ["UI-HUD-UnitFrame-Player-PVP-FFAIcon"] = "FFA",
  ["UI-HUD-UnitFrame-Player-PVP-HordeIcon"] = "Horde",
  ["UI-HUD-UnitFrame-Player-PVP-AllianceIcon"] = "Alliance",
  -- The honor-reward branch, where Blizzard shows prestige art in place of the banner.
  ["honorsystem-portrait-neutral"] = "FFA",
  ["honorsystem-portrait-Horde"] = "Horde",
  ["honorsystem-portrait-Alliance"] = "Alliance",
}

local ResolveRegion = ns.ResolveRegion
local StatusBarTexture = ns.StatusBarTexture
local RemoveMask = ns.RemoveMask

-- The key paths this element works through, all measured from the frame's global name
-- so a focus element can pass its own. Modern's tree is
-- TargetFrame > TargetFrameContainer and TargetFrameContent > Main and Contextual
-- (Mainline/TargetFrame.xml:59, :101, :103, :257), where Classic kept the border art in
-- a textureFrame and hung the bars straight off the frame (Classic/TargetFrame.xml:186,
-- :294, :323). totFrame is the field Blizzard's own CreateTargetofTarget writes
-- (Mainline/TargetFrame.lua:728); reading a Blizzard field is fine, writing one is not.
local function Paths(frameName)
  local contentMain = frameName .. ".TargetFrameContent.TargetFrameContentMain"
  return {
    frame = frameName,
    container = frameName .. ".TargetFrameContainer",
    contentMain = contentMain,
    contextual = frameName .. ".TargetFrameContent.TargetFrameContentContextual",
    healthBars = contentMain .. ".HealthBarsContainer",
    manaBar = contentMain .. ".ManaBar",
    tot = frameName .. ".totFrame",
  }
end

-- One entry per region, applied in order. Restore.lua documents every field.
local function BuildSpec(p)
  local totHealthBar = p.tot .. ".HealthBar"
  local totManaBar = p.tot .. ".ManaBar"

  return {
    -- Frame: Classic/TargetFrame.xml:148-150, mirrored left to right against the player
    -- frame's 21/19/12/15. Modern leaves the left edge open entirely at 0/5/4/9
    -- (Mainline/TargetFrame.xml:55-57).
    --
    -- Classic's own TargetFrame narrows this again in its OnLoad append, to 96/40/10/9,
    -- "allows mouseover over health and mana bars" (Classic/TargetFrame.xml:552). The
    -- template value is the one restored here, per the plan note. It gives a larger
    -- click target than Classic's, and the bars still win the mouse from it: they sit a
    -- frame level above the frame below, the way they do on the player frame.
    {
      path = p.frame,
      hitRectInsets = { 19, 21, 12, 15 },
    },

    -- Border: Classic/TargetFrame.xml:189-195 (the textureFrame's own texture, which
    -- Classic's CheckClassification reaches as self.borderTexture). Which file it wears
    -- is a classification decision, made in RestoreClassification below; only its shape
    -- and its place in the stack are fixed here.
    --
    -- OVERLAY sublevel 0 over bars brought down to the container's level is the player
    -- frame's arrangement, and it lands where Classic had it: Classic's border lived in
    -- textureFrame one level above the frame (Classic/TargetFrame.xml:186) while the
    -- health and mana bars were useParentLevel children of the frame itself (:294, :323),
    -- so the border drew over the bar slot edges. Modern inverts that, parking the
    -- border in TargetFrameContainer one level up (Mainline/TargetFrame.xml:59, :79)
    -- while the bars sit two and three levels up in the content tree (:103, :127, :213).
    {
      path = p.container .. ".FrameTexture",
      drawLayer = { "OVERLAY", 0 },
      size = CLASSIC_BORDER_SIZE,
      point = { point = "CENTER", x = 18.5, y = -4 },
    },

    -- Threat flash: Classic/TargetFrame.xml:153-159. Blizzard decides when it flashes
    -- and what color it flashes, from UnitFrame_UpdateThreatIndicator
    -- (Mainline/UnitFrame.lua:998-1017), which sets a vertex color and nothing else. Its
    -- file, coords, size and anchor are a classification decision too, so they are set
    -- in RestoreClassification; only the draw layer is fixed here.
    --
    -- Classic draws the flash on BACKGROUND of the frame itself, under the portrait,
    -- which Classic draws on BORDER (Classic/TargetFrame.xml:152, :177). Modern's
    -- portrait is BACKGROUND sublevel 1 in this same container
    -- (Mainline/TargetFrame.xml:61-62), so sublevel 0 keeps the flash beneath it.
    { path = p.container .. ".Flash", drawLayer = { "BACKGROUND", 0 } },

    -- Portrait: Classic/TargetFrame.xml:177-181, against Modern's 58x58 at -26,-19
    -- (Mainline/TargetFrame.xml:62-66). Classic relies on SetPortraitTexture's own
    -- circular clip. Blizzard never sets disablePortraitMask on this frame, but writing
    -- a Lua field on a Blizzard frame from addon code taints it either way (ADR 0002),
    -- so the Modern mask region stays and takes the Classic circular mask file, exactly
    -- as the player frame does.
    {
      path = p.container .. ".Portrait",
      size = { 64, 64 },
      point = { point = "TOPRIGHT", x = -24, y = -16 },
    },
    {
      path = p.container .. ".PortraitMask",
      texture = CLASSIC_PORTRAIT_MASK,
      size = { 64, 64 },
      point = { point = "TOPRIGHT", x = -24, y = -16 },
    },

    -- The boss dragon corner: Modern-only art for a boss, elite or rare elite target
    -- (Mainline/TargetFrame.xml:93, set and shown from Mainline/TargetFrame.lua:433-444).
    -- Classic carries all of that in the border file alone, so it stays down. Hidden on
    -- every pass, because CheckClassification re-shows it.
    { path = p.container .. ".BossPortraitFrameTexture", hide = true },

    -- Name background: Classic/TargetFrame.xml:171-175 (nameBackground). Same role and
    -- the same driving call on both branches -- CheckFaction tints it with
    -- UnitSelectionColor (Classic/TargetFrame.lua:292, Mainline/TargetFrame.lua:314) --
    -- over different art, a file on Classic and an atlas on Modern
    -- (Mainline/TargetFrame.xml:106). Blizzard's vertex color is left alone; this entry
    -- changes only what it tints.
    --
    -- The coords are restored explicitly because SetAtlas leaves the atlas's own coords
    -- on the region and SetTexture alone is not guaranteed to clear them.
    --
    -- This is the one region that ends up on the wrong side of the border. Classic drew
    -- nameBackground on the frame, under the textureFrame holding the border
    -- (Classic/TargetFrame.xml:170-175); Modern has it in the content tree two levels up
    -- (Mainline/TargetFrame.xml:103-110), where it draws over the border instead, and it
    -- cannot come down without taking the name and the level text down with it. The
    -- Classic art puts the name slot's bevel outside this 119x19 rect -- the black
    -- backing behind it is 119x25 and its extra height disappears under the health bar
    -- (Classic/TargetFrame.xml:161-166) -- so the two orders should look the same.
    {
      path = p.contentMain .. ".ReputationColor",
      texture = [[Interface\TargetingFrame\UI-TargetingFrame-LevelBackground]],
      texCoord = { 0, 1, 0, 1 },
      size = { 119, 19 },
      point = { point = "TOPRIGHT", x = -90, y = -26 },
    },

    -- Health bar: Classic/TargetFrame.xml:294-298 and :321. Modern splits the bar from
    -- the container that carries its anchor and its text
    -- (Mainline/TargetFrame.xml:127-131, :140-144), so both take the Classic geometry.
    --
    -- Blizzard re-sizes and re-anchors this container per classification
    -- (Mainline/TargetFrame.lua:397-399 and :423-425), which is why it is re-applied on
    -- every pass rather than set once. A StatusBar and its container are Frames, so in
    -- combat the engine holds that geometry back until the fight ends: swapping between
    -- a normal and an elite target mid-fight changes the border at once and the bar
    -- shape late. Known gap.
    {
      path = p.healthBars,
      frameLevel = 1,
      size = { 119, 12 },
      point = { point = "TOPRIGHT", x = -90, y = -45 },
    },
    -- Modern pre-colors the health atlas and sets lockColor through
    -- TargetFrameStatusBarMixin:OnLoad (Mainline/TargetFrame.lua:762-771), so the Classic
    -- green that UnitFrameHealthBar_Update would otherwise apply
    -- (Mainline/UnitFrame.lua:827-829) has to come from here. It is green on both
    -- branches and in every state but disconnected; the target's health bar is never
    -- class-colored.
    {
      path = p.healthBars .. ".HealthBar",
      barTexture = CLASSIC_BAR_FILL,
      barColor = { 0, 1, 0 },
      frameLevel = 1,
      size = { 119, 12 },
    },
    { path = p.healthBars .. ".HealthBarMask", hide = true },
    -- The temporary-max-health-loss bar is Modern-only, but it is a fill on the health
    -- bar, and CheckClassification re-sets its atlas on every pass
    -- (Mainline/TargetFrame.lua:395, :421), so it takes the Classic fill too.
    {
      path = p.healthBars .. ".TempMaxHealthLoss",
      barTexture = CLASSIC_BAR_FILL,
      frameLevel = 1,
    },

    -- Heal prediction and absorb sub-bars: Classic/TargetFrame.xml:300-303, the
    -- fillTexture every TargetFrameBarSegmentTemplate segment inherits.
    { path = p.healthBars .. ".HealthBar.MyHealPredictionBar.Fill", texture = CLASSIC_BAR_FILL },
    { path = p.healthBars .. ".HealthBar.OtherHealPredictionBar.Fill", texture = CLASSIC_BAR_FILL },
    { path = p.healthBars .. ".HealthBar.HealAbsorbBar.Fill", texture = CLASSIC_BAR_FILL },
    { path = p.healthBars .. ".HealthBar.TotalAbsorbBar.Fill", texture = CLASSIC_BAR_FILL },
    -- Each segment already carries useParentLevel through StatusBarOverlaySegmentTemplate,
    -- so these are belt and braces, the same way they are on the player frame.
    { path = p.healthBars .. ".HealthBar.MyHealPredictionBar", frameLevel = 1 },
    { path = p.healthBars .. ".HealthBar.OtherHealPredictionBar", frameLevel = 1 },
    { path = p.healthBars .. ".HealthBar.HealAbsorbBar", frameLevel = 1 },
    { path = p.healthBars .. ".HealthBar.TotalAbsorbBar", frameLevel = 1 },

    -- Mana bar: Classic/TargetFrame.xml:323-327 and :336. Modern widens it to 134x10 and
    -- hangs it off the health bar's container (Mainline/TargetFrame.xml:213-217); the
    -- Classic anchor is measured from the frame instead.
    --
    -- No ManaCostPrediction or FullPower entries: unlike the player's, this mana bar has
    -- neither, carrying only its spark, its text and its mask
    -- (Mainline/TargetFrame.xml:218-254).
    {
      path = p.manaBar,
      barTexture = CLASSIC_BAR_FILL,
      frameLevel = 1,
      size = { 119, 12 },
      point = { point = "TOPRIGHT", x = -90, y = -56 },
    },
    { path = p.manaBar .. ".ManaBarMask", hide = true },

    -- Name: Classic/TargetFrame.xml:197-201. Classic sets no justifyH and so takes the
    -- CENTER default, where Modern sets LEFT over a 90-wide box
    -- (Mainline/TargetFrame.xml:113-118). Without this the name sits at the left edge of
    -- its box instead of centred on the anchor.
    {
      path = p.contentMain .. ".Name",
      justifyH = "CENTER",
      size = { 100, 12 },
      point = { point = "CENTER", x = -34, y = 15 },
    },
    -- Level: Classic/TargetFrame.xml:203-207. The XML warns that this is re-anchored in
    -- code, but only boss frames do that (Classic/TargetFrame.lua:1127); on the target
    -- frame the XML anchor is the one that stands. CheckLevel sets its text, its color
    -- and its visibility on both branches and never moves it.
    --
    -- No justifyH: the level FontString carries no width on either branch, so it sizes
    -- to its text and Classic's LEFT against Modern's CENTER
    -- (Mainline/TargetFrame.xml:119) makes no visible difference.
    --
    -- Tuned by eye against the Anniversary client on 2026-09-17, 1.75px left of
    -- Classic's -35.25, mirroring the nudge the player frame's matching anchor needed.
    -- At the Classic value the level read as off-centre in the Midnight border art even
    -- though the measured rect matched Classic.
    {
      path = p.contentMain .. ".LevelText",
      point = { point = "CENTER", relativePoint = "BOTTOMRIGHT", x = -37, y = 30 },
    },
    -- The "??" skull for a target too high to read, and for a corpse:
    -- Classic/TargetFrame.xml:251-255, centred on the level text, against Modern's atlas
    -- pinned to its top left corner (Mainline/TargetFrame.xml:260-264).
    {
      path = p.contextual .. ".HighLevelTexture",
      texture = CLASSIC_SKULL,
      texCoord = { 0, 1, 0, 1 },
      size = { 16, 16 },
      point = { point = "CENTER", relativeTo = p.contentMain .. ".LevelText" },
    },

    -- Leader and guide: Classic/TargetFrame.xml:257-261 (LeaderIcon). Classic has no
    -- guide icon and a guide leads the group, so both wear the Classic crown rather than
    -- one of them disappearing. Blizzard only shows and hides them, picking between the
    -- two on HasLFGRestrictions (Mainline/TargetFrame.lua:261-270).
    {
      path = p.contextual .. ".LeaderIcon",
      texture = CLASSIC_LEADER_ICON,
      size = { 16, 16 },
      point = { point = "TOPRIGHT", x = -28, y = -14 },
    },
    {
      path = p.contextual .. ".GuideIcon",
      texture = CLASSIC_LEADER_ICON,
      size = { 16, 16 },
      point = { point = "TOPRIGHT", x = -28, y = -14 },
    },

    -- Raid target icon: Classic/TargetFrame.xml:269-273. The one region on this frame
    -- Modern left file-based, on the same file (Mainline/TargetFrame.xml:275), so only
    -- its size and anchor change. No texCoord here on purpose: Blizzard picks the icon
    -- out of the sheet with SetSpriteSheetCell on every update
    -- (Mainline/TargetFrame.lua:672-686), and a fixed texCoord would fight it.
    {
      path = p.contextual .. ".RaidTargetIcon",
      size = { 26, 26 },
      point = { point = "CENTER", relativePoint = "TOPRIGHT", x = -57, y = -18 },
    },

    -- Quest badge: Classic/TargetFrame.xml:275-279, against Modern's atlas over the
    -- portrait (Mainline/TargetFrame.xml:286-290). CheckClassification decides whether
    -- it shows (Mainline/TargetFrame.lua:452-454).
    {
      path = p.contextual .. ".QuestIcon",
      texture = CLASSIC_QUEST_ICON,
      texCoord = { 0, 1, 0, 1 },
      size = { 32, 32 },
      point = { point = "TOPLEFT", relativePoint = "TOPRIGHT", x = -104, y = -16 },
    },

    -- The rare star: Modern-only art, shown for a rare or rare elite target
    -- (Mainline/TargetFrame.xml:281, Mainline/TargetFrame.lua:459-461). Classic says
    -- rare with the border file alone. Hidden on every pass, because
    -- CheckClassification re-shows it.
    { path = p.contextual .. ".BossIcon", hide = true },

    -- PvP banner: Classic/TargetFrame.xml:263-267. Which file it wears is decided by
    -- RestoreClassicPvPIcon below; only its shape is fixed here. The coords are restored
    -- explicitly for the same reason as the name background's.
    {
      path = p.contextual .. ".PvpIcon",
      texCoord = { 0, 1, 0, 1 },
      size = { 64, 64 },
      point = { point = "TOPRIGHT", x = 19, y = -24 },
    },

    -- Three regions on this frame are left Modern on purpose. PetBattleIcon reads the
    -- same file on both branches (Classic/TargetFrame.xml:281,
    -- Mainline/TargetFrame.xml:302) and only its anchor moved, so it is left where
    -- Blizzard put it. NumericalThreat is already built from Classic's own files on both
    -- branches (Mainline/TargetFrame.xml:337, :345). PingIconFrame postdates Classic and
    -- shows only on a ping, which is a Modern feature, not Modern art in a Classic slot.

    -- Target of target: Classic/TargetFrame.xml:408-412, against Modern's 120x49 hung
    -- off the frame's bottom right corner at 12,10 (Mainline/TargetFrame.xml:390-397).
    -- The size matters as much as the anchor, because every ToT region below is measured
    -- from this rect.
    {
      path = p.tot,
      size = { 93, 45 },
      point = { point = "BOTTOMRIGHT", x = -16, y = -14 },
    },
    -- ToT border: Classic/TargetFrame.xml:436-438. Classic gives it no size or anchor of
    -- its own, so it fills the setAllPoints textureFrame it sits in (:433), which is the
    -- ToT frame's own 93x45 rect.
    --
    -- OVERLAY over bars brought down to the ToT frame's level, for the reason the main
    -- border is: Classic raised that textureFrame above the bars in its OnLoad
    -- (Classic/TargetFrame.xml:458), where Modern leaves the border on the frame itself
    -- and the bars a level above it (Mainline/TargetFrame.xml:418, :434, :472).
    {
      path = p.tot .. ".FrameTexture",
      texture = CLASSIC_TOT_BORDER,
      texCoord = { 0.015625, 0.7265625, 0, 0.703125 },
      drawLayer = { "OVERLAY", 0 },
      size = { 93, 45 },
      point = { point = "CENTER", relativeTo = p.tot },
    },
    -- ToT portrait: Classic/TargetFrame.xml:424-428, against Modern's 37x37 at 5,-5
    -- (Mainline/TargetFrame.xml:401-405). Its mask takes the Classic circular file, the
    -- way the main portrait's does.
    {
      path = p.tot .. ".Portrait",
      size = { 35, 35 },
      point = { point = "TOPLEFT", relativeTo = p.tot, x = 6, y = -6 },
    },
    {
      path = p.tot .. ".PortraitMask",
      texture = CLASSIC_PORTRAIT_MASK,
      size = { 35, 35 },
      point = { point = "TOPLEFT", relativeTo = p.tot, x = 6, y = -6 },
    },
    -- ToT bars: Classic/TargetFrame.xml:461-465 and :474-480. Both Modern bars set
    -- lockColor in their own OnLoad (Mainline/TargetFrame.xml:464, :496) and wear an
    -- atlas pre-colored to match, so the Classic green comes from here and the Classic
    -- blue comes from the engine's mana fill.
    --
    -- Level 5 is where Blizzard puts the ToT frame itself, five above the target frame
    -- (Mainline/TargetFrame.lua:727); the bars hang one further up again, which would
    -- put their fills over the border.
    {
      path = totHealthBar,
      barTexture = CLASSIC_BAR_FILL,
      barColor = { 0, 1, 0 },
      frameLevel = 5,
      size = { 46, 7 },
      point = { point = "TOPRIGHT", relativeTo = p.tot, x = -2, y = -15 },
    },
    { path = totHealthBar .. ".HealthBarMask", hide = true },
    {
      path = totManaBar,
      barTexture = CLASSIC_BAR_FILL,
      frameLevel = 5,
      size = { 46, 7 },
      point = { point = "TOPRIGHT", relativeTo = p.tot, x = -2, y = -23 },
    },
    { path = totManaBar .. ".ManaBarMask", hide = true },
    -- ToT name: Classic/TargetFrame.xml:439-443, against Modern's 68-wide box pinned to
    -- the portrait (Mainline/TargetFrame.xml:425-429). Both branches justify it left, so
    -- only the box and the anchor change. The 100 width overhangs the 93-wide frame on
    -- purpose; that is Classic's own number.
    {
      path = p.tot .. ".Name",
      size = { 100, 10 },
      point = { point = "BOTTOMLEFT", relativeTo = p.tot, x = 42, y = 2 },
    },
  }
end

-- Classic's whole classification decision (Classic/TargetFrame.lua:323-386): the border
-- file, and the threat flash's file, coords, size and anchor behind it. Modern makes
-- the same call and reaches the same five cases, but says them in atlases
-- (Mainline/TargetFrame.lua:376-429), and it reads classification for the dragon corner
-- and the rare star too, which the spec table hides.
--
-- UnitClassification carries no secret-return flag in the client's own API
-- documentation, so it is safe to call, and it is the only way to tell minus from
-- normal and rare from rare elite: Blizzard's Modern art merges both of those pairs.
--
-- Ungated, and it can be: both regions are Textures, and the engine's combat gate holds
-- back a Frame only. A target swapped mid-fight gets its border and its flash at once.
local function RestoreClassification(frame, p)
  local classification = UnitClassification(frame.unit)

  local border = ResolveRegion(p.container .. ".FrameTexture")
  if border then
    border:SetTexture(CLASSIC_BORDERS[classification] or CLASSIC_BORDER)
    border:SetTexCoord(CLASSIC_BORDER_TEXCOORD[1], CLASSIC_BORDER_TEXCOORD[2],
      CLASSIC_BORDER_TEXCOORD[3], CLASSIC_BORDER_TEXCOORD[4])
  end

  local flash = ResolveRegion(p.container .. ".Flash")
  if flash then
    local shape = CLASSIC_FLASHES[classification] or FLASH_NORMAL
    flash:SetTexture(shape.texture)
    flash:SetTexCoord(shape.texCoord[1], shape.texCoord[2], shape.texCoord[3], shape.texCoord[4])
    flash:SetSize(shape.size[1], shape.size[2])
    flash:ClearAllPoints()
    flash:SetPoint("TOPLEFT", frame, "TOPLEFT", shape.x, shape.y)
  end
end

-- Blizzard sets the Modern PvP atlas from CheckFaction (Mainline/TargetFrame.lua:336,
-- :352 and :354), or hands the flagged-with-an-honor-reward case to prestige art and
-- hides the banner instead (:328-331, :343-346). Honor prestige postdates Classic, so
-- the prestige art comes down and the banner goes back up in its place, wearing the
-- Classic file for the faction Blizzard's own atlas named.
--
-- Visibility stays Blizzard's decision, unlike on the player frame, where the addon
-- reads the unit and decides for itself. Reading the atlas instead of the unit keeps
-- every secret-flagged call out of this file; see CLASSIC_PVP_FACTION above.
--
-- The prestige regions are hidden here rather than in the spec table, because this is
-- the one pass that can still see whether Blizzard had just shown them. An atlas that
-- maps to nothing leaves the region exactly as Blizzard left it, which is also what
-- happens on a pass that CheckFaction did not trigger: by then the banner is already
-- wearing a Classic file and carries no atlas to read.
--
-- Ungated, like the mana fill: the banner is a Texture, so a target who flags mid-fight
-- gets it without waiting for the fight to end.
local function RestoreClassicPvPIcon(p)
  local icon = ResolveRegion(p.contextual .. ".PvpIcon")
  if not icon then
    return
  end

  local prestigePortrait = ResolveRegion(p.contextual .. ".PrestigePortrait")
  local prestigeBadge = ResolveRegion(p.contextual .. ".PrestigeBadge")

  local faction
  if icon:IsShown() then
    faction = CLASSIC_PVP_FACTION[icon:GetAtlas() or ""]
  elseif prestigePortrait and prestigePortrait:IsShown() then
    faction = CLASSIC_PVP_FACTION[prestigePortrait:GetAtlas() or ""]
  end

  if prestigePortrait then
    prestigePortrait:Hide()
  end
  if prestigeBadge then
    prestigeBadge:Hide()
  end

  if faction then
    icon:SetTexture(CLASSIC_PVP_ICON .. faction)
    icon:SetTexCoord(0, 1, 0, 1)
    icon:Show()
  end
end

-- Blizzard clips the bar fills to the Modern silhouettes, in TargetFrameMixin:OnLoad
-- for the frame's own bars (Mainline/TargetFrame.lua:73-86) and in CreateTargetofTarget
-- for the ToT's (:734, :736). The Classic bars are plain rectangles, so the masks come
-- off the same objects Blizzard put them on. The MaskTexture regions themselves are
-- hidden by the spec table, which covers what the XML masks.
local function UnmaskBars(p)
  local healthBars = ResolveRegion(p.healthBars)
  if healthBars then
    local mask = healthBars.HealthBarMask
    RemoveMask(StatusBarTexture(healthBars.HealthBar), mask)
    RemoveMask(StatusBarTexture(healthBars.TempMaxHealthLoss), mask)
  end

  local manaBar = ResolveRegion(p.manaBar)
  if manaBar then
    RemoveMask(StatusBarTexture(manaBar), manaBar.ManaBarMask)
  end

  local totHealthBar = ResolveRegion(p.tot .. ".HealthBar")
  if totHealthBar then
    RemoveMask(StatusBarTexture(totHealthBar), totHealthBar.HealthBarMask)
  end

  local totManaBar = ResolveRegion(p.tot .. ".ManaBar")
  if totManaBar then
    RemoveMask(StatusBarTexture(totManaBar), totManaBar.ManaBarMask)
  end
end

-- Blizzard re-applies its Modern art from these two, so each one gets a pass after it
-- runs. Both are TargetFrameMixin methods rather than globals, and the mixin is copied
-- onto each frame at load (Mainline/TargetFrame.xml:53), so the hook has to go on the
-- instance: a hook on the mixin table would only reach frames built afterwards.
--
-- Five neighbours are deliberately absent, each checked against the live source:
--   Update            calls CheckFaction and CheckClassification itself
--                     (Mainline/TargetFrame.lua:139-142), and every event that changes
--                     art reaches one of those two (:161-250). Hooking it would only
--                     add a second pass over the same change.
--   CheckLevel        sets text, vertex color and visibility, and moves nothing
--                     (:272-305).
--   CheckPartyLeader  shows and hides the two group icons, nothing else (:261-270).
--   UpdateRaidTargetIcon  picks a cell out of a sprite sheet (:672-686). The file is
--                     already Classic's and the icon's size and anchor are set once; no
--                     texCoord of this addon's is there to be undone.
--   TargetOfTargetMixin:Update  shows and hides the frame and refreshes its values
--                     (:889-913). It re-sets no art, no size and no anchor.
local function ArtMethods(frame)
  return {
    { frame, "CheckClassification" },
    { frame, "CheckFaction" },
  }
end

local function RestoreFrame(frame, frameName)
  local p = Paths(frameName)
  local spec = BuildSpec(p)
  local restorer = ns.NewRestorer(frame)

  local function AfterApply()
    UnmaskBars(p)
    RestoreClassification(frame, p)
    RestoreClassicPvPIcon(p)
    ns.RestoreManaFill(ResolveRegion(p.manaBar))
    ns.RestoreManaFill(ResolveRegion(p.tot .. ".ManaBar"))
  end

  -- Registered before the first pass, because AfterApply restores the fills and the
  -- engine passes over a bar it has not been handed a unit for. Both units come from
  -- the frames Blizzard initialized them with, so a focus element gets focus and
  -- focustarget from the same two reads.
  restorer:RegisterManaBar(ResolveRegion(p.manaBar), frame.unit)
  local tot = ResolveRegion(p.tot)
  if tot then
    restorer:RegisterManaBar(tot.ManaBar, tot.unit)
  end

  restorer:Apply(spec, AfterApply)
  restorer:WatchCombat()

  restorer:Hook(ArtMethods(frame), function()
    restorer:Apply(spec, AfterApply)
  end)
end

local function Restore()
  RestoreFrame(TargetFrame, "TargetFrame")
end

ns.RegisterElement("TargetFrame", Restore)

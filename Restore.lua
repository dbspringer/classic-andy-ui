local _, ns = ...

-- The engine every element restores through. An element owns its spec table and the
-- Blizzard knowledge behind it; this file owns the pass over that table, the combat
-- gate, the mirrors, the hooks and the Classic mana fill.
--
-- One restorer per element, built around that element's root frame: the rect its
-- anchors are measured from, the level its frame levels are offset from, and the
-- frame its mirrors are parented to.

-- Classic's one grayscale bar fill, tinted per bar rather than swapped per state. The
-- mana fill below re-applies it and the element spec tables name it for their other
-- bars, so it lives here rather than in either element.
ns.CLASSIC_BAR_FILL = [[Interface\TargetingFrame\UI-StatusBar]]

-- Resolved at apply time, so a region Blizzard renames comes back nil instead of
-- erroring.
function ns.ResolveRegion(path)
  local region = _G
  for key in string.gmatch(path, "[^.]+") do
    region = region[key]
    if region == nil then
      return nil
    end
  end
  return region
end

-- Both serve the elements' unmask passes. The Classic bars are plain rectangles, so
-- every mask Blizzard clipped a fill with has to come back off.
function ns.StatusBarTexture(bar)
  return bar and bar:GetStatusBarTexture()
end

function ns.RemoveMask(texture, mask)
  if texture and mask then
    texture:RemoveMaskTexture(mask)
  end
end

-- The mana bars this addon restored, and the unit each one reads. Keyed by the bar in
-- this addon's own table rather than flagged with a field on the bar, because a Lua
-- field written on a Blizzard object by addon code taints it (ADR 0002).
local manaBars = {}
local manaHooked = false

-- The Classic mana bar is one grayscale file tinted per power type. Blizzard's
-- UnitFrameManaBar_UpdateType (Mainline/UnitFrame.lua:490) swaps a Modern atlas back
-- in on every power update, so the Classic look is re-applied after it. This mirrors
-- the non-atlas branch of the Classic function (Classic/UnitFrame.lua:463).
--
-- Deliberately outside the combat gate: it sets a texture and a color, never a size,
-- anchor or visibility, so it carries no lockdown risk. Gating it would leave a druid
-- who shifts form mid-fight wearing the Modern fill for the rest of the fight.
--
-- Runs for every unit frame's mana bar, so it returns unless the bar is registered.
function ns.RestoreManaFill(manaBar)
  local unit = manaBar and manaBars[manaBar]
  if not unit then
    return
  end

  -- Blizzard sets powerToken here only when the power type changes, which always
  -- happens before its first return, so by hook time the field is current.
  local powerToken = manaBar.powerToken or select(2, UnitPowerType(unit))

  -- STAGGER and SOUL_FRAGMENTS nest their colors a level down and carry no r of their
  -- own, so an entry without one falls back the way Blizzard's own lookup does.
  local color = PowerBarColor[powerToken]
  if not (color and color.r) then
    color = PowerBarColor["MANA"]
  end

  manaBar:SetStatusBarTexture(ns.CLASSIC_BAR_FILL)
  if UnitIsDead(unit) or UnitIsGhost(unit) then
    manaBar:SetStatusBarColor(0.6, 0.6, 0.6, 0.5)
  else
    manaBar:SetStatusBarColor(color.r, color.g, color.b, 1)
  end

  -- Blizzard fades and desaturates the fill for a dead unit. Classic says that with
  -- color alone, so the texture's own state goes back to neutral.
  local fill = manaBar:GetStatusBarTexture()
  if fill then
    fill:SetDesaturated(false)
    fill:SetAlpha(1)
  end
end

-- A spec table holds one entry per region, applied in order. An entry names its region
-- one of three ways:
--   path           key path from _G, resolved at apply time so a region Blizzard
--                  renames skips its own entry instead of erroring
--   resolve        a function returning the region, for one Blizzard left unkeyed
--   mirror         the name of a Mirror, a texture this addon creates for Classic art
--                  the Modern frame has no region for. Needs `follows` and
--                  `drawLayer`, which is also the layer it is created in.
--
-- Fields, all optional:
--   follows        mirror only, key path of the Modern region whose visibility the
--                  mirror copies
--   texture        Texture:SetTexture
--   barTexture     StatusBar:SetStatusBarTexture
--   barColor       StatusBar:SetStatusBarColor, r g b
--   justifyH       FontString:SetJustifyH
--   texCoord       left, right, top, bottom
--   blendMode      Texture:SetBlendMode
--   drawLayer      Texture:SetDrawLayer, layer and sublevel
--   vertexColor    Texture:SetVertexColor, r g b
--   alpha          Texture:SetAlpha
--   size           width, height
--   point          anchored to the root frame, the rect every Classic anchor is
--                  measured from, unless the entry carries `relativeTo`: a key path
--                  string or a frame, to measure this one anchor from instead
--   frameLevel     Frame:SetFrameLevel, as an offset from the root frame's own level
--   hitRectInsets  left, right, top, bottom
--   hide           a Modern-only region, or a mask the Classic art does not use
function ns.NewRestorer(root)
  local restorer = {}

  local applyPending = false
  local lastSpec, lastAfterApply

  -- Mirrors, keyed by the name their spec entry gives them, and the one frame they are
  -- all drawn on. Kept here rather than on a Blizzard frame, because a Lua field
  -- written on a Blizzard object by addon code taints it (ADR 0002).
  local mirrors = {}
  local mirrorHost

  -- Draw order is frame level first and draw layer second, and at equal level a font
  -- string outranks a texture. Both halves of that bit: a mirror on PlayerFrame itself
  -- sat behind the border art, which lives a level up in PlayerFrameContainer, and a
  -- mirror on PlayerFrameContentContextual sat behind PlayerLevelText, which shares
  -- that level over in PlayerFrameContentMain and covered the rest bubble in game. One
  -- host above both settles it for every mirror at once.
  local function MirrorHost()
    if mirrorHost then
      return mirrorHost
    end

    mirrorHost = CreateFrame("Frame", nil, root)
    mirrorHost:SetAllPoints(root)

    -- The +4 is read off PlayerFrame's own tree, the only one measured so far. The
    -- target frame has a tree of its own and will have to check the number against it.
    --
    -- PlayerFrame's two content frames run one level up and their children run two
    -- (Mainline/PlayerFrame.xml:24, :69, :71, :308). The frames inside those that do not
    -- carry useParentLevel run three: HitIndicator (:97), PlayerRestLoop (:380) and
    -- GroupIndicator (:421). Four clears every one of them.
    --
    -- It does not clear the ready check, which raises itself to five through
    -- ReadyCheckStatusTemplate (Mainline/PlayerFrame.xml:377). That is the Classic result
    -- too: Classic raised its own ready check the same way (Classic/PlayerFrame.xml:178)
    -- to two levels above the frame holding the state icons.
    mirrorHost:SetFrameLevel(root:GetFrameLevel() + 4)

    -- The stack the spec table and this host add up to, bottom to top:
    --   +1  bar fills on BACKGROUND and ARTWORK, then the border on OVERLAY 0, then the
    --       bar text on OVERLAY 1
    --   +2  name, level, status glow, and the contextual icons Blizzard still owns
    --   +4  every mirror, ordered among themselves by drawLayer
    --   +5  the ready check, which outranks the mirrors on purpose
    return mirrorHost
  end

  local function EnsureMirror(entry)
    local mirror = mirrors[entry.mirror]
    if mirror then
      return mirror
    end

    local followed = ns.ResolveRegion(entry.follows)
    if not followed then
      return nil
    end

    -- Every mirror shares the host's frame level, so `drawLayer` is the whole of their
    -- order against each other. It follows the order the Classic XML gave the regions
    -- they stand in for.
    mirror = MirrorHost():CreateTexture(nil, entry.drawLayer[1], nil, entry.drawLayer[2])
    mirrors[entry.mirror] = mirror

    -- A mirror reads no game state. It copies one region's visibility, and Blizzard
    -- reaches that region through all three calls, so all three are hooked. The sync
    -- below covers the state the region is already in at load.
    --
    -- hooksecurefunc is the one sanctioned way to put a function on a Blizzard object:
    -- the client installs it from secure code, so unlike the direct field write in
    -- ADR 0002 it leaves the object untainted.
    local function Follow()
      mirror:SetShown(followed:IsShown())
    end
    hooksecurefunc(followed, "Show", Follow)
    hooksecurefunc(followed, "Hide", Follow)
    hooksecurefunc(followed, "SetShown", Follow)
    Follow()

    return mirror
  end

  -- Art -- what a region is made of -- goes on every pass, in combat included: the
  -- combat swords and the combat flash have to be Classic the moment the fight starts,
  -- and SetTexture, SetTexCoord, SetBlendMode, SetStatusBarTexture, SetStatusBarColor
  -- and SetJustifyH carry no lockdown risk.
  --
  -- Geometry and visibility -- SetSize, SetPoint, SetHitRectInsets, Hide -- are held
  -- back, because they are restricted on a protected frame and every region below an
  -- element's root frame is protected. applyPending brings the pass back on
  -- PLAYER_REGEN_ENABLED.
  --
  -- A Mirror is exempt: it is this addon's own texture on an unprotected path, so
  -- nothing about it is restricted and gating it would strand it for a whole fight.
  local function ApplyEntry(region, entry, locked)
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
    if entry.drawLayer then
      region:SetDrawLayer(entry.drawLayer[1], entry.drawLayer[2])
    end
    if entry.alpha then
      region:SetAlpha(entry.alpha)
    end
    if entry.vertexColor then
      local color = entry.vertexColor
      region:SetVertexColor(color[1], color[2], color[3])
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

    if not (entry.size or entry.point or entry.frameLevel or entry.hitRectInsets or entry.hide) then
      return
    end
    if locked and not entry.mirror then
      applyPending = true
      return
    end

    -- Gated with the geometry: frame level is a protected-frame call, and the whole tree
    -- under the root frame is protected. Entries are ordered parents first, because
    -- setting a frame's level carries its descendants with it.
    if entry.frameLevel then
      -- Every bar frame is flagged useParentLevel in Blizzard's XML, and the client
      -- re-asserts that flag over SetFrameLevel: in game the bars stayed at their parent's
      -- level after the call. Clearing the flag first makes the level stick.
      if region.SetUsingParentLevel then
        region:SetUsingParentLevel(false)
      end
      region:SetFrameLevel(root:GetFrameLevel() + entry.frameLevel)
    end
    if entry.size then
      region:SetSize(entry.size[1], entry.size[2])
    end
    if entry.point then
      -- Cleared first because the Modern anchor is often a different point than the
      -- Classic one, and SetPoint would leave both in place.
      local anchor = entry.point
      local relativeTo = anchor.relativeTo or root
      if type(relativeTo) == "string" then
        relativeTo = ns.ResolveRegion(relativeTo)
      end
      -- A relativeTo that no longer resolves skips the anchor rather than falling
      -- through to SetPoint's parent default, which would move the region somewhere
      -- Classic never put it.
      if relativeTo then
        region:ClearAllPoints()
        region:SetPoint(anchor.point, relativeTo, anchor.relativePoint or anchor.point,
          anchor.x or 0, anchor.y or 0)
      end
    end
    if entry.hitRectInsets then
      local insets = entry.hitRectInsets
      region:SetHitRectInsets(insets[1], insets[2], insets[3], insets[4])
    end
    if entry.hide then
      region:Hide()
    end
  end

  -- One pass over the spec table. Combat is read once so every entry in the pass agrees
  -- about it; ApplyEntry decides per operation what that means. The element's afterApply
  -- tail runs last, on that same reading.
  function restorer:Apply(spec, afterApply)
    lastSpec, lastAfterApply = spec, afterApply

    local locked = InCombatLockdown()
    applyPending = false

    for _, entry in ipairs(spec) do
      local region
      if entry.mirror then
        region = EnsureMirror(entry)
      elseif entry.resolve then
        region = entry.resolve()
      else
        region = ns.ResolveRegion(entry.path)
      end
      if region then
        ApplyEntry(region, entry, locked)
      end
    end

    if afterApply then
      afterApply(locked)
    end
  end

  -- An afterApply tail that holds a call back for the lockdown says so here, so the
  -- pass comes round again with the gated entries.
  function restorer:MarkPending()
    applyPending = true
  end

  function restorer:WatchCombat()
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:SetScript("OnEvent", function()
      if applyPending then
        restorer:Apply(lastSpec, lastAfterApply)
      end
    end)
  end

  -- Blizzard re-applies its Modern art from each function in the list, so each one gets
  -- a pass after it runs. An entry is either the name of a global function, or an
  -- { object, "Method" } pair for a mixin-based frame, whose methods are copied onto the
  -- instance at load and so cannot be reached by name. Either form is skipped when it is
  -- not there, so a function Blizzard renames drops its hook instead of erroring at load.
  function restorer:Hook(list, fn)
    for _, target in ipairs(list) do
      if type(target) == "table" then
        local object, method = target[1], target[2]
        if object and type(object[method]) == "function" then
          hooksecurefunc(object, method, fn)
        end
      elseif type(_G[target]) == "function" then
        hooksecurefunc(target, fn)
      end
    end
  end

  function restorer:Mirror(name)
    return mirrors[name]
  end

  -- Hooked once for the whole addon rather than through Hook: UnitFrameManaBar_UpdateType
  -- fires on every power tick of every unit frame, where a full pass would be far too
  -- much work, and it must not wait for combat.
  function restorer:RegisterManaBar(bar, unit)
    if not bar then
      return
    end
    manaBars[bar] = unit

    if not manaHooked and type(UnitFrameManaBar_UpdateType) == "function" then
      manaHooked = true
      hooksecurefunc("UnitFrameManaBar_UpdateType", ns.RestoreManaFill)
    end
  end

  return restorer
end

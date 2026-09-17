local ADDON_NAME, ns = ...

-- Elements register here. Each entry is { name = string, restore = function }.
-- Core calls every restore function once at login when the switch is on.
ns.elements = {}

function ns.RegisterElement(name, restore)
  table.insert(ns.elements, { name = name, restore = restore })
end

local function IsEnabled()
  return ClassicAndyUIDB.enabled
end

local function RestoreAll()
  for _, element in ipairs(ns.elements) do
    element.restore()
  end
end

-- Reskins hide and swap textures on Blizzard's frames. Undoing that at runtime
-- is not clean, so the switch takes effect on the next UI reload.
StaticPopupDialogs["CLASSICANDYUI_RELOAD"] = {
  text = "%s",
  button1 = RELOADUI,
  button2 = LATER,
  OnAccept = function() ReloadUI() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

local function Toggle()
  ClassicAndyUIDB.enabled = not ClassicAndyUIDB.enabled
  local message = IsEnabled()
    and ns.L["Classic Andy UI is now enabled. Reload the UI to apply?"]
    or ns.L["Classic Andy UI is now disabled. Reload the UI to apply?"]
  StaticPopup_Show("CLASSICANDYUI_RELOAD", message)
end

SLASH_CLASSICANDYUI1 = "/cau"
SLASH_CLASSICANDYUI2 = "/classicandy"
SlashCmdList.CLASSICANDYUI = Toggle

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    ClassicAndyUIDB = ClassicAndyUIDB or { enabled = true }
  elseif event == "PLAYER_LOGIN" and IsEnabled() then
    RestoreAll()
  end
end)

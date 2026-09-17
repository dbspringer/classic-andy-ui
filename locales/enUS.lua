local _, ns = ...

-- Keys are the enUS display text, so a missing translation shows English.
-- A translation lives in locales/<locale>.lua, starts with
-- `if GetLocale() ~= "<locale>" then return end`, then assigns into ns.L.
ns.L = setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

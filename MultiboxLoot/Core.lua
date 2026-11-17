local ADDON, ns = ...
ns.ADDON = ADDON

local DEFAULTS = { enabled = true, debug = false, quiet = false }

local handlers = {}
local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(handlers[event]) do
    fn(...)
  end
end)

-- Register fn for a WoW event. fn receives the event's arguments (not the event name).
function ns.On(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    frame:RegisterEvent(event)
  end
  table.insert(handlers[event], fn)
end

function ns.Print(msg)
  print("|cffe0a95a[MBL]|r " .. msg)
end

function ns.PlayerName()
  return (UnitName("player"))
end

ns.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  MultiboxLootDB = MultiboxLootDB or {}
  for key, value in pairs(DEFAULTS) do
    if MultiboxLootDB[key] == nil then MultiboxLootDB[key] = value end
  end
  ns.db = MultiboxLootDB
end)

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

-- Forever names are "First Last" with a space and no realm. UnitName gives only the first name;
-- GetUnitName(unit, true) gives the whole name, the same form addon message senders use.
function ns.FullName(unit)
  return GetUnitName(unit, true)
end

function ns.PlayerName()
  return ns.FullName("player")
end

ns.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  MultiboxLootDB = MultiboxLootDB or {}
  for key, value in pairs(DEFAULTS) do
    if MultiboxLootDB[key] == nil then MultiboxLootDB[key] = value end
  end
  ns.db = MultiboxLootDB
end)

local function onOff(value)
  return value and "on" or "off"
end

SLASH_MULTIBOXLOOT1 = "/mbl"
SlashCmdList.MULTIBOXLOOT = function(input)
  local cmd, arg = input:match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()
  local db = ns.db
  if cmd == "on" or cmd == "off" then
    db.enabled = cmd == "on"
    ns.Print("distribution " .. cmd)
  elseif cmd == "bank" then
    -- Stored as typed; matched to a group member by Roster.Resolve (first or full name, any case).
    db.bankAlt = arg ~= "" and arg or nil
    ns.Print("bank alt: " .. (db.bankAlt or "none"))
  elseif cmd == "debug" then
    db.debug = not db.debug
    ns.Print("debug (dry run) " .. onOff(db.debug))
  elseif cmd == "quiet" then
    db.quiet = not db.quiet
    ns.Print("quiet " .. onOff(db.quiet))
  elseif cmd == "status" then
    ns.Roster.PrintStatus()
  else
    ns.Print("/mbl on | off | bank <name> | status | debug | quiet")
  end
end

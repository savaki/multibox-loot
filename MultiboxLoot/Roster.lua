local _, ns = ...

local Roster = { members = {} }
ns.Roster = Roster

Roster.PREFIX = "MBLOOT"

-- Skill line names we report (English client). Forever has no Jewelcrafting.
Roster.PROFESSIONS = {
  Alchemy = true, Blacksmithing = true, Cooking = true, Enchanting = true,
  Engineering = true, ["First Aid"] = true, Fishing = true, Herbalism = true,
  Leatherworking = true, Mining = true, Skinning = true, Tailoring = true,
}

-- Wire format: "Cooking=80,Tailoring=145;12" — professions, then free bag slots.
function Roster.Encode(professions, freeSlots)
  local parts = {}
  for name, skill in pairs(professions) do
    parts[#parts + 1] = name .. "=" .. skill
  end
  table.sort(parts)
  return table.concat(parts, ",") .. ";" .. freeSlots
end

function Roster.Decode(msg)
  local profPart, slotPart = msg:match("^(.*);(%d+)$")
  if not profPart then return nil end
  local professions = {}
  for name, skill in profPart:gmatch("([^,=]+)=(%d+)") do
    professions[name] = tonumber(skill)
  end
  return { professions = professions, freeSlots = tonumber(slotPart) }
end

local function scanProfessions()
  -- Expand collapsed headers, back to front so earlier indexes stay valid.
  for i = GetNumSkillLines(), 1, -1 do
    local _, isHeader, isExpanded = GetSkillLineInfo(i)
    if isHeader and not isExpanded then ExpandSkillHeader(i) end
  end
  local professions = {}
  for i = 1, GetNumSkillLines() do
    local name, isHeader, _, rank = GetSkillLineInfo(i)
    if not isHeader and Roster.PROFESSIONS[name] then
      professions[name] = rank
    end
  end
  return professions
end

-- Free slots in general-purpose bags only (bag family 0); profession bags are ignored.
local function countFreeSlots()
  local getFree = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
  local total = 0
  for bag = 0, NUM_BAG_SLOTS do
    local free, family = getFree(bag)
    if free and family == 0 then total = total + free end
  end
  return total
end

function Roster.Broadcast()
  local professions, freeSlots = scanProfessions(), countFreeSlots()
  Roster.members[ns.PlayerName()] = { professions = professions, freeSlots = freeSlots, seen = time() }
  if IsInGroup() then
    C_ChatInfo.SendAddonMessage(Roster.PREFIX, Roster.Encode(professions, freeSlots), IsInRaid() and "RAID" or "PARTY")
  end
end

-- Coalesce bursts of events (BAG_UPDATE fires per bag) into one broadcast.
local broadcastPending = false
local function broadcastSoon()
  if broadcastPending then return end
  broadcastPending = true
  C_Timer.After(2, function()
    broadcastPending = false
    Roster.Broadcast()
  end)
end

local function prune()
  local me = ns.PlayerName()
  for name in pairs(Roster.members) do
    if name ~= me and not (UnitInParty(name) or UnitInRaid(name)) then
      Roster.members[name] = nil
    end
  end
end

local function groupUnits()
  local units = {}
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
  else
    units[1] = "player"
    for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
  end
  return units
end

function Roster.PrintStatus()
  local db = ns.db
  ns.Print(("enabled: %s, debug: %s, quiet: %s, bank alt: %s"):format(
    tostring(db.enabled), tostring(db.debug), tostring(db.quiet), db.bankAlt or "none"))
  for _, unit in ipairs(groupUnits()) do
    local name = UnitName(unit)
    local entry = name and Roster.members[name]
    if entry then
      local profs = {}
      for profession, skill in pairs(entry.professions) do
        profs[#profs + 1] = profession .. " " .. skill
      end
      table.sort(profs)
      ns.Print(("%s: %s — %d free slots (%ds ago)"):format(
        name, #profs > 0 and table.concat(profs, ", ") or "no professions",
        entry.freeSlots, time() - entry.seen))
    elseif name then
      ns.Print(name .. ": no report (addon not installed or not loaded?)")
    end
  end
end

ns.On("PLAYER_LOGIN", function()
  C_ChatInfo.RegisterAddonMessagePrefix(Roster.PREFIX)
  broadcastSoon()
end)

ns.On("GROUP_ROSTER_UPDATE", function()
  prune()
  broadcastSoon()
end)

ns.On("SKILL_LINES_CHANGED", broadcastSoon)
ns.On("BAG_UPDATE", broadcastSoon)

ns.On("CHAT_MSG_ADDON", function(prefix, msg, _, sender)
  if prefix ~= Roster.PREFIX then return end
  local entry = Roster.Decode(msg)
  if not entry then return end
  entry.seen = time()
  Roster.members[Ambiguate(sender, "none")] = entry
end)

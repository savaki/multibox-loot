local _, ns = ...

local Roster = { members = {} }
ns.Roster = Roster

Roster.PREFIX = "MBLOOT"

-- Skill line ID → the profession name used in Rules.CHAINS. IDs are the same in every client
-- language. Forever has no Jewelcrafting.
Roster.SKILL_LINES = {
  [171] = "Alchemy", [164] = "Blacksmithing", [185] = "Cooking", [333] = "Enchanting",
  [202] = "Engineering", [129] = "First Aid", [356] = "Fishing", [182] = "Herbalism",
  [165] = "Leatherworking", [186] = "Mining", [393] = "Skinning", [197] = "Tailoring",
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

-- Forever has no skill list (GetNumSkillLines/GetSkillLineInfo are nil), so professions come from
-- GetProfessions, which returns up to six indexes with nil gaps.
function Roster.ScanProfessions()
  local professions = {}
  for _, index in pairs({ GetProfessions() }) do
    local _, _, rank, _, _, _, skillLine = GetProfessionInfo(index)
    local name = Roster.SKILL_LINES[skillLine]
    if name then professions[name] = rank end
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
  local professions, freeSlots = Roster.ScanProfessions(), countFreeSlots()
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

-- names: list of { full = "First Last", first = "First" }. Returns lowercased name → full name.
-- Full names are indexed first so a first name never shadows someone's full name.
function Roster.NameIndex(names)
  local index = {}
  for _, n in ipairs(names) do
    index[n.full:lower()] = n.full
  end
  for _, n in ipairs(names) do
    local key = n.first and n.first:lower()
    if key and not index[key] then index[key] = n.full end
  end
  return index
end

-- Any spelling of a group member's name (first or full, any case) → their full name.
-- Names not in the group come back unchanged.
function Roster.Resolve(index, name)
  if not name then return nil end
  return index[name:lower()] or name
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

function Roster.GroupIndex()
  local names = {}
  local units = groupUnits()
  units[#units + 1] = "player" -- raid units include us, a party's don't; duplicates are harmless
  for _, unit in ipairs(units) do
    local full = ns.FullName(unit)
    if full then names[#names + 1] = { full = full, first = UnitName(unit) } end
  end
  return Roster.NameIndex(names)
end

local function prune()
  local index = Roster.GroupIndex()
  for name in pairs(Roster.members) do
    if not index[name:lower()] then Roster.members[name] = nil end
  end
end

function Roster.PrintStatus()
  local db = ns.db
  ns.Print(("enabled: %s, debug: %s, quiet: %s, bank alt: %s"):format(
    tostring(db.enabled), tostring(db.debug), tostring(db.quiet), db.bankAlt or "none"))
  for _, unit in ipairs(groupUnits()) do
    local name = ns.FullName(unit)
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

-- Sent after login/reload so members that broadcast before we were listening resend.
local REQUEST = "?"

ns.On("PLAYER_LOGIN", function()
  C_ChatInfo.RegisterAddonMessagePrefix(Roster.PREFIX)
  broadcastSoon()
  if IsInGroup() then
    C_ChatInfo.SendAddonMessage(Roster.PREFIX, REQUEST, IsInRaid() and "RAID" or "PARTY")
  end
end)

ns.On("GROUP_ROSTER_UPDATE", function()
  prune()
  broadcastSoon()
end)

ns.On("SKILL_LINES_CHANGED", broadcastSoon)
ns.On("BAG_UPDATE", broadcastSoon)

ns.On("CHAT_MSG_ADDON", function(prefix, msg, channel, sender)
  if prefix ~= Roster.PREFIX then return end
  if msg == REQUEST then
    broadcastSoon()
    return
  end
  local entry = Roster.Decode(msg)
  if not entry then return end
  entry.seen = time()
  Roster.members[Roster.Resolve(Roster.GroupIndex(), sender)] = entry
  if ns.db and ns.db.debug then
    ns.Print(("roster from %s on %s: %s"):format(sender, tostring(channel), msg))
  end
end)

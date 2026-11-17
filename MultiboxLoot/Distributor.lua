local _, ns = ...

local Distributor = {}
ns.Distributor = Distributor

local GIVE_TIMEOUT = 1     -- seconds to wait for LOOT_SLOT_CLEARED before assuming the give failed
local LOOT_SLOT_ITEM = 1

-- Per loot window: { full = {name=true}, skip = {slot=true}, pending = {slot, name, token}, warned = bool }
local state

local function lootMethod()
  if C_PartyInfo and C_PartyInfo.GetLootMethod then return C_PartyInfo.GetLootMethod() end
  return GetLootMethod()
end

local function isMasterLooter()
  local method, partyIndex, raidIndex = lootMethod()
  local isMaster = method == "master"
    or (Enum.LootMethod ~= nil and method == Enum.LootMethod.Masterlooter)
  if not isMaster then return false end
  if IsInRaid() then
    return raidIndex ~= nil and UnitIsUnit("raid" .. raidIndex, "player")
  end
  return partyIndex == 0
end

local function eligibleFor(slot)
  local eligible = {}
  for i = 1, MAX_RAID_MEMBERS do
    local name = GetMasterLootCandidate(slot, i)
    if name then eligible[Ambiguate(name, "none")] = i end
  end
  return eligible
end

-- Returns nil for slots we never touch (coins, quest items), otherwise a decision table.
local function decide(slot)
  if GetLootSlotType(slot) ~= LOOT_SLOT_ITEM then return nil end
  local link = GetLootSlotLink(slot)
  if not link then return nil end
  local _, _, quantity, _, _, _, isQuestItem, questID = GetLootSlotInfo(slot)
  local itemID, _, _, _, _, classID, subClassID = GetItemInfoInstant(link)
  if ns.Items.IsQuest(isQuestItem, questID, classID) then
    if ns.db.debug then
      ns.Print(("slot %d %s: quest item (isQuestItem=%s questID=%s class=%s) — skipped"):format(
        slot, link, tostring(isQuestItem), tostring(questID), tostring(classID)))
    end
    return nil
  end
  local category = ns.Items.Classify(itemID, classID, subClassID)
  local eligible = eligibleFor(slot)
  local name, reason = ns.Rules.PickRecipient(category, {
    roster = ns.Roster.members,
    eligible = eligible,
    full = state.full,
    bankAlt = ns.db.bankAlt,
    masterLooter = ns.PlayerName(),
  })
  return {
    slot = slot, link = link, quantity = quantity, itemID = itemID,
    classID = classID, subClassID = subClassID, category = category,
    name = name, reason = reason, index = name and eligible[name],
  }
end

local function printDebug(d)
  ns.Print(("slot %d %s x%d id=%s class=%s/%s category=%s → %s (%s)"):format(
    d.slot, d.link, d.quantity, tostring(d.itemID), tostring(d.classID), tostring(d.subClassID),
    tostring(d.category), d.name or "nobody", d.reason or "-"))
end

function Distributor.ProcessNext()
  if not state or state.pending then return end
  for slot = 1, GetNumLootItems() do
    if not state.skip[slot] and LootSlotHasItem(slot) then
      local d = decide(slot)
      if not d then
        state.skip[slot] = true
      elseif ns.db.debug then
        printDebug(d)
        state.skip[slot] = true
      elseif not d.name then
        state.skip[slot] = true
        if not state.warned then
          state.warned = true
          ns.Print("nobody can take " .. d.link .. " — left on corpse")
        end
      else
        local token = {}
        state.pending = { slot = slot, name = d.name, token = token }
        if not ns.db.quiet then
          ns.Print(("%s x%d → %s (%s)"):format(d.link, d.quantity, d.name, d.reason))
        end
        GiveMasterLoot(slot, d.index)
        C_Timer.After(GIVE_TIMEOUT, function() Distributor.OnTimeout(token) end)
        return
      end
    end
  end
end

-- The slot wasn't cleared in time: treat the recipient as full and re-decide that slot.
function Distributor.OnTimeout(token)
  if not state or not state.pending or state.pending.token ~= token then return end
  state.full[state.pending.name] = true
  state.pending = nil
  Distributor.ProcessNext()
end

ns.On("LOOT_OPENED", function()
  state = nil
  if not ns.db.enabled or not isMasterLooter() then return end
  state = { full = {}, skip = {}, warned = false }
  Distributor.ProcessNext()
end)

ns.On("LOOT_SLOT_CLEARED", function(slot)
  if state and state.pending and state.pending.slot == slot then
    state.pending = nil
    Distributor.ProcessNext()
  end
end)

ns.On("LOOT_CLOSED", function()
  state = nil
end)

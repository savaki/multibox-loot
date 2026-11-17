local _, ns = ...

local Rules = {}
ns.Rules = Rules

-- Category → professions to try, in order. Gathering professions never receive what they
-- gather (it's for the crafters); the one exception is ore, which a miner smelts.
Rules.CHAINS = {
  Leather = { "Leatherworking" },
  Cloth = { "Tailoring" },
  Cooking = { "Cooking" },
  Herb = { "Alchemy" },
  HerbSeed = { "Alchemy" },
  Ore = { "Mining", "Blacksmithing", "Engineering" }, -- the miner smelts it
  Metal = { "Blacksmithing", "Engineering" },
  Enchanting = { "Enchanting" },
  EngineeringParts = { "Engineering" },
  Gem = { "Blacksmithing", "Engineering", "Leatherworking", "Tailoring", "Enchanting" },
  ArcaneCrystal = { "Alchemy", "Enchanting" },
}

-- Category → class whose highest-level member gets it, ahead of any profession chain.
Rules.CLASS_ROUTES = {
  Scroll = "MAGE",
}

-- A name can receive if it is eligible for this corpse, not marked full, and
-- doesn't report zero free slots (unknown free slots count as room).
local function canReceive(ctx, name)
  if not name or not ctx.eligible[name] or ctx.full[name] then return false end
  local entry = ctx.roster[name]
  return entry == nil or entry.freeSlots == nil or entry.freeSlots > 0
end

-- ctx:
--   roster       name -> { professions = { [profession] = skill }, freeSlots = n }
--   eligible     name -> master loot candidate index for this slot
--   full         name -> true if a give to them failed on this corpse
--   bankAlt      name or nil
--   masterLooter name
--   units        name -> { class = "MAGE", level = 40 } for group members (class routes only)
-- Returns name, reason ("Tailoring 145", "Mage 42", "bank", "master looter"), or nil.
function Rules.PickRecipient(category, ctx)
  local class = category and Rules.CLASS_ROUTES[category]
  if class then
    local best, bestLevel
    for name, unit in pairs(ctx.units or {}) do
      if unit.class == class and canReceive(ctx, name)
        and (bestLevel == nil or unit.level > bestLevel or (unit.level == bestLevel and name < best)) then
        best, bestLevel = name, unit.level
      end
    end
    if best then return best, class:sub(1, 1) .. class:sub(2):lower() .. " " .. bestLevel end
  end
  local chain = category and Rules.CHAINS[category]
  if chain then
    for _, profession in ipairs(chain) do
      local best, bestSkill
      for name, entry in pairs(ctx.roster) do
        local skill = entry.professions and entry.professions[profession]
        if skill and canReceive(ctx, name)
          and (bestSkill == nil or skill > bestSkill or (skill == bestSkill and name < best)) then
          best, bestSkill = name, skill
        end
      end
      if best then return best, profession .. " " .. bestSkill end
    end
  end
  if canReceive(ctx, ctx.bankAlt) then return ctx.bankAlt, "bank" end
  if canReceive(ctx, ctx.masterLooter) then return ctx.masterLooter, "master looter" end
  return nil
end

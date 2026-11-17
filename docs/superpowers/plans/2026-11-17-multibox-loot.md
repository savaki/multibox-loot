# MultiboxLoot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A WoW: Forever addon that automatically master-loots profession materials to the party member whose profession uses them.

**Architecture:** Two pure-Lua modules (`Items.lua` classifies items, `Rules.lua` picks a recipient) hold all decision logic and are tested offline with plain `lua`. Thin WoW-API layers sit around them: `Roster.lua` syncs each character's professions and free bag slots over addon messages, and `Distributor.lua` drives the master loot window one slot at a time. `Core.lua` owns the namespace, event dispatch, SavedVariables and the `/mbl` slash command.

**Tech Stack:** Lua 5.1 (WoW runtime; tests run under the local Lua 5.4 — avoid `goto`, `//`, `utf8`), WoW Classic-family API (`GiveMasterLoot`, `GetMasterLootCandidate`, `C_ChatInfo.SendAddonMessage`).

**Spec:** `docs/superpowers/specs/2026-11-17-multibox-loot-design.md`

---

## File Structure

| Path | Responsibility |
|---|---|
| `MultiboxLoot/MultiboxLoot.toc` | Addon manifest: Interface version, SavedVariables, load order |
| `MultiboxLoot/Core.lua` | Namespace, event registry `ns.On`, `ns.Print`, SavedVariables defaults, `/mbl` |
| `MultiboxLoot/Items.lua` | `Items.Classify(itemID, classID, subClassID)`, `Items.IsQuest(...)` — pure |
| `MultiboxLoot/Rules.lua` | `Rules.CHAINS`, `Rules.PickRecipient(category, ctx)` — pure |
| `MultiboxLoot/Roster.lua` | `Roster.Encode/Decode` (pure) + broadcast/receive glue, `Roster.PrintStatus` |
| `MultiboxLoot/Distributor.lua` | Loot window handling, `GiveMasterLoot`, timeout retry, debug dry run |
| `tests/run.lua` | Tiny test harness; loads addon files with a stub namespace |
| `tests/items_test.lua`, `tests/rules_test.lua`, `tests/roster_test.lua` | Offline tests |

Every addon file begins with `local _, ns = ...` — WoW passes `(addonName, namespaceTable)` to each file. The test harness mimics this with `loadfile(path)("MultiboxLoot", ns)`.

---

### Task 1: Scaffold — TOC, Core, test harness

**Files:**
- Create: `MultiboxLoot/MultiboxLoot.toc`
- Create: `MultiboxLoot/Core.lua`
- Create: `tests/run.lua`

- [ ] **Step 1: Create the TOC**

`MultiboxLoot/MultiboxLoot.toc`:
```
## Interface: 11507
## Title: MultiboxLoot
## Notes: Master-loots profession materials to the party member who uses them.
## Version: 0.1.0
## SavedVariables: MultiboxLootDB

Core.lua
Items.lua
Rules.lua
Roster.lua
Distributor.lua
```
(`11507` is Classic Era 1.15.7; Task 7 confirms Forever's number in game.)

- [ ] **Step 2: Create Core.lua (no slash command yet)**

`MultiboxLoot/Core.lua`:
```lua
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
```

- [ ] **Step 3: Create the test harness**

`tests/run.lua`:
```lua
-- Run from the repo root: lua tests/run.lua
local ns = { On = function() end }

local function loadAddonFile(file)
  assert(loadfile("MultiboxLoot/" .. file))("MultiboxLoot", ns)
end

local passed, failed = 0, 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL " .. name .. ": " .. tostring(err))
  end
end

local function eq(actual, expected, label)
  if actual ~= expected then
    error((label and (label .. ": ") or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local ADDON_FILES = {}
local TEST_FILES = {}

for _, file in ipairs(ADDON_FILES) do loadAddonFile(file) end
for _, file in ipairs(TEST_FILES) do
  assert(loadfile("tests/" .. file))(test, eq, ns)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
```

- [ ] **Step 4: Run the harness**

Run: `lua tests/run.lua`
Expected: `0 passed, 0 failed`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add MultiboxLoot tests
git commit -m "Scaffold MultiboxLoot addon and test harness

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Items — classification and quest detection

**Files:**
- Create: `tests/items_test.lua`
- Create: `MultiboxLoot/Items.lua`
- Modify: `tests/run.lua` (the `ADDON_FILES` / `TEST_FILES` lists)

- [ ] **Step 1: Write the failing tests**

`tests/items_test.lua`:
```lua
local test, eq, ns = ...
local Items = ns.Items

test("table: Linen Cloth is Cloth", function() eq(Items.Classify(2589), "Cloth") end)
test("table: Light Leather is Leather", function() eq(Items.Classify(2318), "Leather") end)
test("table: Light Hide is Leather", function() eq(Items.Classify(783), "Leather") end)
test("table: Peacebloom is Herb", function() eq(Items.Classify(2447), "Herb") end)
test("table: Copper Ore is Metal", function() eq(Items.Classify(2770), "Metal") end)
test("table: Coarse Stone is Metal", function() eq(Items.Classify(2836), "Metal") end)
test("table: Strange Dust is Enchanting", function() eq(Items.Classify(10940), "Enchanting") end)
test("table: Chunk of Boar Meat is Cooking", function() eq(Items.Classify(769), "Cooking") end)
test("table: Malachite is Gem", function() eq(Items.Classify(774), "Gem") end)

test("table wins over generic subclass", function() eq(Items.Classify(2589, 7, 0), "Cloth") end)
test("fallback: tradeskill Cloth subclass", function() eq(Items.Classify(999999, 7, 5), "Cloth") end)
test("fallback: tradeskill Herb subclass", function() eq(Items.Classify(999999, 7, 9), "Herb") end)
test("fallback: tradeskill Parts subclass", function() eq(Items.Classify(999999, 7, 1), "EngineeringParts") end)
test("fallback: generic Trade Goods subclass is unclassified", function() eq(Items.Classify(999999, 7, 0), nil) end)
test("fallback: armor is unclassified", function() eq(Items.Classify(999999, 4, 2), nil) end)
test("no class info is unclassified", function() eq(Items.Classify(999999), nil) end)

test("quest: isQuestItem flag", function() eq(Items.IsQuest(true, nil, 7), true) end)
test("quest: quest starter", function() eq(Items.IsQuest(false, 1234, 7), true) end)
test("quest: quest item class", function() eq(Items.IsQuest(false, nil, 12), true) end)
test("quest: ordinary trade good", function() eq(Items.IsQuest(false, nil, 7), false) end)
test("quest: questID 0 is not a quest", function() eq(Items.IsQuest(nil, 0, 7), false) end)
```

- [ ] **Step 2: Register the files in the harness**

In `tests/run.lua` replace the two list lines with:
```lua
local ADDON_FILES = { "Items.lua" }
local TEST_FILES = { "items_test.lua" }
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `lua tests/run.lua`
Expected: error `cannot open MultiboxLoot/Items.lua` (non-zero exit).

- [ ] **Step 4: Implement Items.lua**

`MultiboxLoot/Items.lua`:
```lua
local _, ns = ...

local Items = {}
ns.Items = Items

local TRADESKILL_CLASS = 7
local QUEST_CLASS = 12

-- Tradeskill subclass → category, used only when an item isn't in the ID tables.
-- Many Classic items carry the generic subclass 0 ("Trade Goods"), which stays unclassified.
local BY_SUBCLASS = {
  [1] = "EngineeringParts", -- Parts
  [3] = "EngineeringParts", -- Devices
  [4] = "Gem",              -- Jewelcrafting
  [5] = "Cloth",
  [6] = "Leather",
  [7] = "Metal",            -- Metal & Stone
  [8] = "Cooking",
  [9] = "Herb",
  [12] = "Enchanting",
}

local BY_ID = {}

local function add(category, ids)
  for _, id in ipairs(ids) do
    BY_ID[id] = category
  end
end

add("Cloth", {
  2589,  -- Linen Cloth
  2592,  -- Wool Cloth
  4306,  -- Silk Cloth
  4338,  -- Mageweave Cloth
  14047, -- Runecloth
  14256, -- Felcloth
})

add("Leather", {
  2934,  -- Ruined Leather Scraps
  2318,  -- Light Leather
  2319,  -- Medium Leather
  4234,  -- Heavy Leather
  4304,  -- Thick Leather
  8170,  -- Rugged Leather
  783,   -- Light Hide
  4232,  -- Medium Hide
  4235,  -- Heavy Hide
  8169,  -- Thick Hide
  8171,  -- Rugged Hide
  8154,  -- Scorpid Scale
  7286,  -- Black Whelp Scale
  15417, -- Devilsaur Leather
  17012, -- Core Leather
})

add("Herb", {
  2447,  -- Peacebloom
  765,   -- Silverleaf
  2449,  -- Earthroot
  785,   -- Mageroyal
  2450,  -- Briarthorn
  2452,  -- Swiftthistle
  2453,  -- Bruiseweed
  3820,  -- Stranglekelp
  3355,  -- Wild Steelbloom
  3369,  -- Grave Moss
  3356,  -- Kingsblood
  3357,  -- Liferoot
  3818,  -- Fadeleaf
  3821,  -- Goldthorn
  3358,  -- Khadgar's Whisker
  3819,  -- Wintersbite
  4625,  -- Firebloom
  8831,  -- Purple Lotus
  8836,  -- Arthas' Tears
  8838,  -- Sungrass
  8839,  -- Blindweed
  8845,  -- Ghost Mushroom
  8846,  -- Gromsblood
  13464, -- Golden Sansam
  13463, -- Dreamfoil
  13465, -- Mountain Silversage
  13466, -- Plaguebloom
  13467, -- Icecap
  13468, -- Black Lotus
})

add("Metal", {
  2770,  -- Copper Ore
  2771,  -- Tin Ore
  2772,  -- Iron Ore
  2775,  -- Silver Ore
  2776,  -- Gold Ore
  3858,  -- Mithril Ore
  7911,  -- Truesilver Ore
  10620, -- Thorium Ore
  11370, -- Dark Iron Ore
  2840,  -- Copper Bar
  3576,  -- Tin Bar
  2841,  -- Bronze Bar
  3575,  -- Iron Bar
  3859,  -- Steel Bar
  2842,  -- Silver Bar
  3577,  -- Gold Bar
  3860,  -- Mithril Bar
  6037,  -- Truesilver Bar
  12359, -- Thorium Bar
  2835,  -- Rough Stone
  2836,  -- Coarse Stone
  2838,  -- Heavy Stone
  7912,  -- Solid Stone
  12365, -- Dense Stone
})

add("Enchanting", {
  10940, -- Strange Dust
  11083, -- Soul Dust
  11137, -- Vision Dust
  11176, -- Dream Dust
  16204, -- Illusion Dust
  10938, -- Lesser Magic Essence
  10939, -- Greater Magic Essence
  10998, -- Lesser Astral Essence
  11082, -- Greater Astral Essence
  11134, -- Lesser Mystic Essence
  11135, -- Greater Mystic Essence
  11174, -- Lesser Nether Essence
  11175, -- Greater Nether Essence
  16202, -- Lesser Eternal Essence
  16203, -- Greater Eternal Essence
  10978, -- Small Glimmering Shard
  11084, -- Large Glimmering Shard
  11138, -- Small Glowing Shard
  11139, -- Large Glowing Shard
  11177, -- Small Radiant Shard
  11178, -- Large Radiant Shard
  14343, -- Small Brilliant Shard
  14344, -- Large Brilliant Shard
  20725, -- Nexus Crystal
})

add("Cooking", {
  769,   -- Chunk of Boar Meat
  723,   -- Goretusk Liver
  729,   -- Stringy Vulture Meat
  1015,  -- Lean Wolf Flank
  2672,  -- Stringy Wolf Meat
  2673,  -- Coyote Meat
  2674,  -- Crawler Meat
  2675,  -- Crawler Claw
  3173,  -- Bear Meat
  3685,  -- Raptor Egg
  3712,  -- Turtle Meat
  3730,  -- Big Bear Meat
  3731,  -- Lion Meat
  5503,  -- Clam Meat
  5504,  -- Tangy Clam Meat
  6289,  -- Raw Longjaw Mud Snapper
  6291,  -- Raw Brilliant Smallfish
  6889,  -- Small Egg
  12037, -- Mystery Meat
  12184, -- Raptor Flesh
  12203, -- Red Wolf Meat
  12205, -- White Spider Meat
  12207, -- Giant Egg
  12208, -- Tender Wolf Meat
})

add("Gem", {
  774,   -- Malachite
  818,   -- Tigerseye
  1210,  -- Shadowgem
  1206,  -- Moss Agate
  1705,  -- Lesser Moonstone
  1529,  -- Jade
  3864,  -- Citrine
  7909,  -- Aquamarine
  7910,  -- Star Ruby
  12361, -- Blue Sapphire
  12363, -- Arcane Crystal
  12364, -- Huge Emerald
  12799, -- Large Opal
  12800, -- Azerothian Diamond
})

-- Returns a category name, or nil when the item isn't a known profession material.
function Items.Classify(itemID, classID, subClassID)
  local category = BY_ID[itemID]
  if category then return category end
  if classID == TRADESKILL_CLASS then return BY_SUBCLASS[subClassID] end
  return nil
end

-- isQuestItem/questID come from GetLootSlotInfo, classID from GetItemInfoInstant.
function Items.IsQuest(isQuestItem, questID, classID)
  if isQuestItem then return true end
  if questID and questID ~= 0 then return true end
  return classID == QUEST_CLASS
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `lua tests/run.lua`
Expected: `21 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add MultiboxLoot/Items.lua tests
git commit -m "Add item classification and quest-item detection

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Rules — recipient selection

**Files:**
- Create: `tests/rules_test.lua`
- Create: `MultiboxLoot/Rules.lua`
- Modify: `tests/run.lua` (lists)

- [ ] **Step 1: Write the failing tests**

`tests/rules_test.lua`:
```lua
local test, eq, ns = ...
local Rules = ns.Rules

-- Builds a ctx where everyone listed in roster is eligible unless overridden.
local function ctx(opts)
  local roster = opts.roster or {}
  local eligible = opts.eligible
  if not eligible then
    eligible = {}
    local i = 1
    for name in pairs(roster) do eligible[name] = i; i = i + 1 end
    if opts.bankAlt then eligible[opts.bankAlt] = 90 end
    eligible.Leader = 99
  end
  return {
    roster = roster,
    eligible = eligible,
    full = opts.full or {},
    bankAlt = opts.bankAlt,
    masterLooter = "Leader",
  }
end

local function member(professions, freeSlots)
  return { professions = professions, freeSlots = freeSlots or 10 }
end

test("highest skill wins", function()
  local name, reason = Rules.PickRecipient("Cloth", ctx({ roster = {
    Ann = member({ Tailoring = 100 }),
    Bob = member({ Tailoring = 150 }),
  } }))
  eq(name, "Bob"); eq(reason, "Tailoring 150")
end)

test("equal skill breaks tie by name", function()
  local name = Rules.PickRecipient("Cloth", ctx({ roster = {
    Zed = member({ Tailoring = 100 }),
    Ann = member({ Tailoring = 100 }),
  } }))
  eq(name, "Ann")
end)

test("ineligible higher skill is skipped", function()
  local name = Rules.PickRecipient("Cloth", ctx({
    roster = { Ann = member({ Tailoring = 100 }), Bob = member({ Tailoring = 150 }) },
    eligible = { Ann = 1, Leader = 2 },
  }))
  eq(name, "Ann")
end)

test("full-this-corpse is skipped", function()
  local name = Rules.PickRecipient("Cloth", ctx({
    roster = { Ann = member({ Tailoring = 100 }), Bob = member({ Tailoring = 150 }) },
    full = { Bob = true },
  }))
  eq(name, "Ann")
end)

test("zero free slots is skipped", function()
  local name = Rules.PickRecipient("Cloth", ctx({ roster = {
    Ann = member({ Tailoring = 100 }),
    Bob = member({ Tailoring = 150 }, 0),
  } }))
  eq(name, "Ann")
end)

test("chain falls through to next profession", function()
  local name, reason = Rules.PickRecipient("Metal", ctx({ roster = {
    Eng = member({ Engineering = 80 }),
    Min = member({ Mining = 200 }),
  } }))
  eq(name, "Eng"); eq(reason, "Engineering 80")
end)

test("chain prefers first profession", function()
  local name = Rules.PickRecipient("Metal", ctx({ roster = {
    Smith = member({ Blacksmithing = 10 }),
    Eng = member({ Engineering = 200 }),
  } }))
  eq(name, "Smith")
end)

test("no profession match goes to bank alt", function()
  local name, reason = Rules.PickRecipient("Herb", ctx({
    roster = { Ann = member({ Tailoring = 100 }) },
    bankAlt = "Mule",
  }))
  eq(name, "Mule"); eq(reason, "bank")
end)

test("unclassified goes to bank alt", function()
  local name = Rules.PickRecipient(nil, ctx({ roster = {}, bankAlt = "Mule" }))
  eq(name, "Mule")
end)

test("bank alt full falls back to master looter", function()
  local name, reason = Rules.PickRecipient(nil, ctx({
    roster = { Mule = member({}, 0) },
    bankAlt = "Mule",
  }))
  eq(name, "Leader"); eq(reason, "master looter")
end)

test("bank alt ineligible falls back to master looter", function()
  local name = Rules.PickRecipient(nil, ctx({
    roster = {},
    bankAlt = "Mule",
    eligible = { Leader = 1 },
  }))
  eq(name, "Leader")
end)

test("no bank alt set goes to master looter", function()
  eq(Rules.PickRecipient(nil, ctx({ roster = {} })), "Leader")
end)

test("master looter full returns nil", function()
  local name = Rules.PickRecipient(nil, ctx({ roster = {}, full = { Leader = true } }))
  eq(name, nil)
end)
```

- [ ] **Step 2: Register the files in the harness**

In `tests/run.lua`:
```lua
local ADDON_FILES = { "Items.lua", "Rules.lua" }
local TEST_FILES = { "items_test.lua", "rules_test.lua" }
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `lua tests/run.lua`
Expected: error `cannot open MultiboxLoot/Rules.lua`.

- [ ] **Step 4: Implement Rules.lua**

`MultiboxLoot/Rules.lua`:
```lua
local _, ns = ...

local Rules = {}
ns.Rules = Rules

-- Category → professions to try, in order.
Rules.CHAINS = {
  Leather = { "Leatherworking" },
  Cloth = { "Tailoring" },
  Cooking = { "Cooking" },
  Herb = { "Alchemy" },
  Metal = { "Blacksmithing", "Engineering", "Mining" },
  Enchanting = { "Enchanting" },
  EngineeringParts = { "Engineering" },
  Gem = { "Blacksmithing", "Jewelcrafting" },
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
-- Returns name, reason ("Tailoring 145", "bank", "master looter"), or nil.
function Rules.PickRecipient(category, ctx)
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `lua tests/run.lua`
Expected: `34 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add MultiboxLoot/Rules.lua tests
git commit -m "Add profession chains and recipient selection

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Roster — wire format and party sync

**Files:**
- Create: `tests/roster_test.lua`
- Create: `MultiboxLoot/Roster.lua`
- Modify: `tests/run.lua` (lists)

- [ ] **Step 1: Write the failing tests**

`tests/roster_test.lua`:
```lua
local test, eq, ns = ...
local Roster = ns.Roster

test("encode sorts professions", function()
  eq(Roster.Encode({ Tailoring = 145, Cooking = 80 }, 12), "Cooking=80,Tailoring=145;12")
end)

test("encode with no professions", function()
  eq(Roster.Encode({}, 3), ";3")
end)

test("decode round trip", function()
  local entry = Roster.Decode("Cooking=80,First Aid=150,Tailoring=145;12")
  eq(entry.professions.Cooking, 80)
  eq(entry.professions["First Aid"], 150)
  eq(entry.professions.Tailoring, 145)
  eq(entry.freeSlots, 12)
end)

test("decode with no professions", function()
  local entry = Roster.Decode(";0")
  eq(next(entry.professions), nil)
  eq(entry.freeSlots, 0)
end)

test("decode rejects garbage", function()
  eq(Roster.Decode("hello"), nil)
end)
```

- [ ] **Step 2: Register the files in the harness**

In `tests/run.lua`:
```lua
local ADDON_FILES = { "Items.lua", "Rules.lua", "Roster.lua" }
local TEST_FILES = { "items_test.lua", "rules_test.lua", "roster_test.lua" }
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `lua tests/run.lua`
Expected: error `cannot open MultiboxLoot/Roster.lua`.

- [ ] **Step 4: Implement Roster.lua**

`MultiboxLoot/Roster.lua`:
```lua
local _, ns = ...

local Roster = { members = {} }
ns.Roster = Roster

Roster.PREFIX = "MBLOOT"

-- Skill line names we report (English client).
Roster.PROFESSIONS = {
  Alchemy = true, Blacksmithing = true, Cooking = true, Enchanting = true,
  Engineering = true, ["First Aid"] = true, Fishing = true, Herbalism = true,
  Jewelcrafting = true, Leatherworking = true, Mining = true, Skinning = true,
  Tailoring = true,
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `lua tests/run.lua`
Expected: `39 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add MultiboxLoot/Roster.lua tests
git commit -m "Add roster sync of professions and free bag slots

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Distributor — master loot window

No offline tests: this file is WoW-API glue around the tested pure functions. It is verified in Task 7.

**Files:**
- Create: `MultiboxLoot/Distributor.lua`

- [ ] **Step 1: Implement Distributor.lua**

`MultiboxLoot/Distributor.lua`:
```lua
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
```

- [ ] **Step 2: Syntax check against Lua**

Run: `luac -p MultiboxLoot/*.lua && lua tests/run.lua`
Expected: no `luac` output, then `39 passed, 0 failed`.

- [ ] **Step 3: Commit**

```bash
git add MultiboxLoot/Distributor.lua
git commit -m "Add master loot distributor with timeout fallback and dry-run debug

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Slash commands

**Files:**
- Modify: `MultiboxLoot/Core.lua` (append at end)

- [ ] **Step 1: Append the slash command to Core.lua**

Append to `MultiboxLoot/Core.lua`:
```lua
local function onOff(value)
  return value and "on" or "off"
end

-- "muleguy" → "Muleguy" (ASCII only; non-ASCII bytes are left as typed).
local function normalizeName(name)
  return name:sub(1, 1):upper() .. name:sub(2):lower()
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
    db.bankAlt = arg ~= "" and normalizeName(arg) or nil
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
```

- [ ] **Step 2: Syntax check and tests**

Run: `luac -p MultiboxLoot/*.lua && lua tests/run.lua`
Expected: `39 passed, 0 failed`.

- [ ] **Step 3: Commit**

```bash
git add MultiboxLoot/Core.lua
git commit -m "Add /mbl slash commands

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Install and verify in game (user-assisted)

- [ ] **Step 1: Locate the Forever AddOns folder**

Run: `ls "/Applications/World of Warcraft"`
Expected: a Forever folder (e.g. `_forever_`). If none, ask the user for the install path.

- [ ] **Step 2: Symlink the addon**

```bash
ln -s "$PWD/MultiboxLoot" "/Applications/World of Warcraft/<forever folder>/Interface/AddOns/MultiboxLoot"
```

- [ ] **Step 3: Confirm the Interface number (user)**

User runs `/dump select(4, GetBuildInfo())` in game. If it isn't `11507`, update `## Interface:` in `MultiboxLoot.toc`, `/reload`, and commit.

- [ ] **Step 4: Dry run (user)**

On the leader: `/mbl debug`, `/mbl bank <alt>`, `/mbl status` (every party member should list professions and free slots). Kill a few mobs including a quest mob, open the corpse, and check the printed decisions. Confirm quest items print as skipped.

- [ ] **Step 5: Live (user)**

`/mbl debug` again to turn dry run off. Loot several corpses; confirm cloth/leather/meat/etc. land on the right characters.

- [ ] **Step 6: Commit any fixes** found during verification, adding item IDs to `Items.lua` with a matching test in `tests/items_test.lua`.

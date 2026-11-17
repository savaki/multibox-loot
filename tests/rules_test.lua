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

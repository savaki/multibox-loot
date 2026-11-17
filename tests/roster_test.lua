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

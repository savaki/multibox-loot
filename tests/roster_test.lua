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

-- Simulates the WoW: Forever client: no skill list (GetNumSkillLines/GetSkillLineInfo are nil),
-- professions come from GetProfessions/GetProfessionInfo instead.
test("scan reads professions by skill line on Forever", function()
  local infos = {
    [3] = { "Tailoring", 145, 197 },
    [7] = { "Cooking", 80, 185 },
    [8] = { "First Aid", 150, 129 },
    [9] = { "Archaeology", 10, 794 }, -- not a profession we route
  }
  GetNumSkillLines, GetSkillLineInfo = nil, nil
  GetProfessions = function() return 3, nil, 9, nil, 7, 8 end
  GetProfessionInfo = function(index)
    local info = infos[index]
    return info[1], "icon", info[2], 300, 0, 0, info[3]
  end
  local professions = Roster.ScanProfessions()
  GetProfessions, GetProfessionInfo = nil, nil
  eq(professions.Tailoring, 145)
  eq(professions.Cooking, 80)
  eq(professions["First Aid"], 150)
  eq(professions.Archaeology, nil)
end)

test("scan with no professions", function()
  GetProfessions = function() end
  GetProfessionInfo = function() error("should not be called") end
  local professions = Roster.ScanProfessions()
  GetProfessions, GetProfessionInfo = nil, nil
  eq(next(professions), nil)
end)

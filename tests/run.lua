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

local ADDON_FILES = { "Items.lua" }
local TEST_FILES = { "items_test.lua" }

for _, file in ipairs(ADDON_FILES) do loadAddonFile(file) end
for _, file in ipairs(TEST_FILES) do
  assert(loadfile("tests/" .. file))(test, eq, ns)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)

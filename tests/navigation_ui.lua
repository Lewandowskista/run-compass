package.path = "./?.lua;./?/init.lua;" .. package.path

local BrowserModel = require("runcompass.browser_model")

local function assertEqual(actual, expected, message)
  if actual ~= expected then error((message or "values differ") .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")") end
end

local function assertTrue(value, message)
  if not value then error(message or "expected truthy value") end
end

local function entries()
  local result = {
    { id = "boss.mega_satan", name = "Mega Satan", kind = "boss", status = "routable" },
    { id = "boss.delirium", name = "Delirium", kind = "boss", status = "routable" },
    { id = 100, name = "The Halo", kind = "collectible", status = "locked", requiredCharacterToken = "isaac" },
    { id = 101, name = "A Mark", kind = "collectible", status = "locked", completionMark = "hush" },
    { id = 102, name = "Donation Reward", kind = "collectible", status = "instructional_only", unlockMethod = "donation" }
  }
  for id = 201, 216 do
    result[#result + 1] = { id = id, name = string.format("Boss %02d", id - 200), kind = "boss", status = "routable" }
  end
  return result
end

local function testBuildsLiveCategoryCounts()
  local model = BrowserModel.build(entries(), {}, { category = "boss_routes", selectedIndex = 1, scrollOffset = 1 }, 10)
  assertEqual(model.categories[1].id, "boss_routes", "boss routes should be the first category")
  assertEqual(model.categories[1].count, 18, "boss routes should include all bosses")
  assertEqual(model.categories[2].id, "item_unlocks", "item unlocks should be the second category")
end

local function testKeepsSelectedRowInPageWindow()
  local model = BrowserModel.build(entries(), {}, { category = "boss_routes", selectedIndex = 14 }, 10)
  assertEqual(model.scrollOffset, 5, "selection should scroll into the page window")
  assertEqual(model.rows[10].absoluteIndex, 14, "selected goal should occupy the final visible row")
end

local function testKeepsFinalSelectionInPersistedPageWindow()
  local model = BrowserModel.build(entries(), {}, { category = "boss_routes", selectedIndex = 18, scrollOffset = 9 }, 10)
  assertEqual(model.scrollOffset, 9, "final selection should retain its persisted page offset")
  assertEqual(model.rows[10].absoluteIndex, 18, "final selected goal should remain visible")
end

local function testResolvesSortedGoalDetails()
  local model = BrowserModel.build(entries(), {}, { category = "boss_routes", selectedIndex = 1 }, 10)
  assertEqual(model.details.name, "Boss 01", "boss goals should sort by name")
  assertTrue(model.details.statusLabel ~= nil, "details should expose a status label")
  assertEqual(model.details.lines[2], "Character: Any", "details should provide a default character line")
  assertEqual(model.details.lines[3], "Difficulty: Normal / Hard", "details should provide a default difficulty line")
  assertEqual(model.details.lines[4], "Method: Boss route", "boss details should provide the default method")
end

local tests = { testBuildsLiveCategoryCounts, testKeepsSelectedRowInPageWindow, testKeepsFinalSelectionInPersistedPageWindow, testResolvesSortedGoalDetails }
for index, test in ipairs(tests) do
  test()
  print("navigation ok " .. index)
end
print("4 navigation UI tests passed")

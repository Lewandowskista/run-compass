package.path = "./?.lua;./?/init.lua;" .. package.path

local BrowserModel = require("runcompass.browser_model")
local UI = require("runcompass.ui")

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

local function testAdvancesPastInclusivePageEndpoint()
  local model = BrowserModel.build(entries(), {}, { category = "boss_routes", selectedIndex = 11, scrollOffset = 1 }, 10)
  assertEqual(model.scrollOffset, 2, "selection beyond the inclusive page endpoint should advance the window")
  assertEqual(model.rows[10].absoluteIndex, 11, "advanced window should include the selected goal")
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

local function testFiltersCatalogStatusWhileShowingCurrentRunStatus()
  local model = BrowserModel.build({
    { id = "boss.completed", name = "Completed Boss", kind = "boss", status = "already_unlocked" }
  }, {}, { category = "boss_routes", filters = { status = "already_unlocked" } }, 10)
  assertEqual(model.resultCount, 1, "catalog completion status should remain filterable")
  assertEqual(model.goals[1].status, "already_unlocked", "goal should retain catalog status")
  assertEqual(model.details.currentRunStatus, "complete", "details should retain resolved current-run status")
  assertEqual(model.details.lines[#model.details.lines], "Current run: Completed", "current-run status should use a readable label")
end

local function testExposesCategoryAndRowContract()
  local model = BrowserModel.build(entries(), {}, { category = "boss_routes", selectedIndex = 1 }, 10)
  local row = model.rows[1]
  assertEqual(model.categories[1].label, "Boss Routes", "categories should expose display labels")
  assertEqual(row.absoluteIndex, 1, "rows should expose their absolute index")
  assertEqual(row.id, 201, "rows should expose goal ids")
  assertEqual(row.name, "Boss 01", "rows should expose goal names")
  assertEqual(row.status, "routable", "rows should expose catalog status")
  assertEqual(row.statusLabel, "Eligible", "rows should expose readable status labels")
  assertTrue(row.selected, "rows should identify the selected goal")
  assertTrue(row.entry ~= nil and row.entry.id == row.id, "rows should retain their entry")
end

local function testClampsOneBasedScrollForEmptyAndShortCategories()
  local empty = BrowserModel.build({}, {}, { category = "boss_routes", selectedIndex = 99, scrollOffset = 0 }, 10)
  assertEqual(empty.scrollOffset, 1, "empty categories should use a one-based scroll offset")
  assertEqual(empty.selectedIndex, 0, "empty categories should use a safe selection")
  assertEqual(empty.details.name, "No matching goals", "empty categories should expose safe details")
  local short = BrowserModel.build({ { id = "boss.short", name = "Short Boss", kind = "boss", status = "routable" } }, {}, { category = "boss_routes", selectedIndex = 99, scrollOffset = 99 }, 10)
  assertEqual(short.scrollOffset, 1, "short categories should clamp to the first one-based offset")
  assertEqual(short.selectedIndex, 1, "short categories should clamp selection")
  assertEqual(short.details.name, "Short Boss", "short categories should retain selected details")
end

local function uiFixture()
  local triggered = nil
  local selected = nil
  local keyboard = {
    KEY_UP = 101, KEY_DOWN = 102, KEY_LEFT = 103, KEY_RIGHT = 104,
    KEY_ENTER = 105, KEY_ESCAPE = 106, KEY_TAB = 107, KEY_S = 108,
    KEY_L = 109, KEY_BACKSPACE = 110, KEY_A = 200, KEY_Z = 225,
    KEY_SPACE = 111, KEY_MINUS = 112, KEY_APOSTROPHE = 113,
    KEY_COMMA = 114, KEY_PERIOD = 115, KEY_SLASH = 116
  }
  local controller = {
    DPAD_UP = 1, DPAD_DOWN = 2, DPAD_LEFT = 3, DPAD_RIGHT = 4,
    BUTTON_A = 5, BUTTON_B = 6, BUTTON_X = 7, BUTTON_Y = 8,
    LEFT_SHOULDER = 9, RIGHT_SHOULDER = 10
  }
  local ui = UI.new({
    input = { IsButtonTriggered = function(code) return code == triggered end },
    keyboard = keyboard,
    controller = controller,
    state = {
      bindings = { keyboardGoal = 901, keyboardToggle = 902, controllerGoal = 903, controllerToggle = 904 },
      browser = { category = "boss_routes", kind = "all", status = "all", alphabet = "all", character = "all", unlockMethod = "all", completionMark = "all" },
      hud = { visible = true },
      pinned = false
    },
    entries = entries(),
    onGoalSelected = function(goal) selected = goal end
  })
  ui.open = true
  return {
    ui = ui,
    keyboard = keyboard,
    controller = controller,
    press = function(code) triggered = code; ui:input(); triggered = nil end,
    selected = function() return selected end
  }
end

local function testShouldersChangeCategories()
  local fixture = uiFixture()
  fixture.press(fixture.controller.RIGHT_SHOULDER)
  assertEqual(fixture.ui.browserState.category, "item_unlocks", "right shoulder should advance the category")
  fixture.press(fixture.controller.LEFT_SHOULDER)
  assertEqual(fixture.ui.browserState.category, "boss_routes", "left shoulder should restore the category")
end

local function testControllerSelectsAbsoluteGoalAfterScrolling()
  local fixture = uiFixture()
  for _ = 1, 13 do fixture.press(fixture.controller.DPAD_DOWN) end
  fixture.press(fixture.controller.BUTTON_A)
  assertEqual(fixture.selected().name, "Boss 14", "controller selection should use the absolute highlighted goal")
end

local function testDpadMovesBetweenCategoryAndGoalPanes()
  local fixture = uiFixture()
  fixture.press(fixture.keyboard.KEY_LEFT)
  assertEqual(fixture.ui.browserState.focusedPane, "categories", "left should focus categories")
  fixture.press(fixture.keyboard.KEY_DOWN)
  assertEqual(fixture.ui.browserState.category, "item_unlocks", "down in categories should change active category")
  fixture.press(fixture.keyboard.KEY_RIGHT)
  assertEqual(fixture.ui.browserState.focusedPane, "goals", "right should return focus to goals")
end

local function testSearchPreservesSpacesAndPunctuation()
  local fixture = uiFixture()
  fixture.ui.query = "King"
  fixture.press(fixture.keyboard.KEY_SPACE)
  fixture.press(fixture.keyboard.KEY_APOSTROPHE)
  assertEqual(fixture.ui.query, "King '", "search should preserve spaces and apostrophes")
end

local tests = { testBuildsLiveCategoryCounts, testKeepsSelectedRowInPageWindow, testAdvancesPastInclusivePageEndpoint, testKeepsFinalSelectionInPersistedPageWindow, testResolvesSortedGoalDetails, testFiltersCatalogStatusWhileShowingCurrentRunStatus, testExposesCategoryAndRowContract, testClampsOneBasedScrollForEmptyAndShortCategories, testShouldersChangeCategories, testControllerSelectsAbsoluteGoalAfterScrolling, testDpadMovesBetweenCategoryAndGoalPanes, testSearchPreservesSpacesAndPunctuation }
for index, test in ipairs(tests) do
  test()
  print("navigation ok " .. index)
end
print("12 navigation UI tests passed")

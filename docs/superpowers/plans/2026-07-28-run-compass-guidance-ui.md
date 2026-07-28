# Run Compass Actionable Guidance UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat goal list and generic exploration output with an organized three-pane browser, ranked frontier routing, visible build decisions, and correctly positioned door/entity guidance.

**Architecture:** Introduce pure browser-view and frontier-ranking modules, then route all actionable planner results through a common recommendation finalizer. Keep input/rendering in `ui.lua`, scoring in planner/build modules, and engine access in focused adapters so `Planner.plan(snapshot, goal, previousRecommendation)` remains the only public planner API.

**Tech Stack:** The Binding of Isaac Repentance+ Lua API, Repentogon feature probes, optional EID, Mod Config Menu, Lua tables, Fengari test runner, PNG/ANM2 assets, PowerShell packaging/deployment.

---

## File Map

### Create

- `runcompass/browser_model.lua` — derives categories, goal rows, details, counts, and scrolling from catalog data.
- `runcompass/frontier.lua` — builds and ranks legitimately revealed frontier candidates.
- `runcompass/recommendation.lua` — finalizes actionable planner results and attaches build decisions.
- `runcompass/hud.lua` — produces compact HUD view data and resolves live door coordinates.
- `tests/navigation_ui.lua` — browser model, pane navigation, scrolling, readable labels, HUD layout tests.
- `tests/guidance.lua` — frontier ranking, explore decisions, EID boundary, marker lifecycle tests.
- `gfx/ui/guidance-markers.png` — original 128×32 action-marker spritesheet.
- `gfx/ui/guidance-markers.anm2` — TAKE/CAUTION/SKIP marker animations.

### Modify

- `runcompass/browser.lua` — retain filtering and add deterministic status/category helpers used by the view model.
- `runcompass/ui.lua` — three-pane input/rendering, compact card, sprite markers, held-detail control.
- `runcompass/planner.lua` — use ranked frontiers and the shared finalizer for `ok` and `explore`.
- `runcompass/presentation.lua` — generate compact and expanded explanation lines.
- `runcompass/strings.lua` — add all browser, route, action, status, and control labels.
- `runcompass/game.lua` — retain stable visible-choice positions and choice metadata required by markers.
- `runcompass/save.lua` — schema v4 browser preferences and detail bindings.
- `runcompass/mcm.lua` — expose detail bindings and compact-HUD settings.
- `main.lua` — inject browser model dependencies, readable selected goal, sprite factory, and strengthened fingerprints.
- `package.json` — run the new suites.
- `metadata.xml` — version 1.2.0.
- `docs/CONTROLS.md` — document three-pane and compact-HUD controls.
- `docs/RELEASES.md` — add 1.2.0 release notes and manual gates.
- `README.md` — update the feature and control summaries.

## Task 1: Add Browser View-Model and Scroll Semantics

**Files:**

- Create: `runcompass/browser_model.lua`
- Create: `tests/navigation_ui.lua`
- Modify: `runcompass/browser.lua`
- Modify: `package.json`

- [ ] **Step 1: Add the new test suite to the test command**

Change `package.json`:

```json
{
  "name": "run-compass-rep-plus",
  "private": true,
  "scripts": {
    "test": "fengari tests/run.lua && fengari tests/performance.lua && fengari tests/build_guide.lua && fengari tests/navigation_ui.lua && fengari tests/guidance.lua"
  },
  "devDependencies": {
    "fengari-node-cli": "0.1.0"
  }
}
```

Create a temporary `tests/guidance.lua` runner so the command can execute before Task 4:

```lua
package.path = "./?.lua;./?/init.lua;" .. package.path
print("0 guidance tests passed")
```

- [ ] **Step 2: Write failing category and scrolling tests**

Create `tests/navigation_ui.lua`:

```lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local BrowserModel = require("runcompass.browser_model")

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
  end
end

local function assertTrue(value, message)
  if not value then error(message or "expected truthy value") end
end

local function entries()
  local result = {
    { id = "boss.mega_satan", name = "Mega Satan", kind = "boss", status = "routable" },
    { id = "boss.delirium", name = "Delirium", kind = "boss", status = "routable" },
    { id = 100, name = "The Halo", kind = "collectible", status = "locked", requiredCharacterToken = "isaac" },
    { id = 101, name = "A Mark", kind = "collectible", completionMark = "hush", status = "locked" },
    { id = 102, name = "Donation Reward", kind = "collectible", unlockMethod = "donation", status = "instructional_only" }
  }
  for index = 1, 16 do
    result[#result + 1] = { id = 200 + index, name = string.format("Boss %02d", index), kind = "boss", status = "routable" }
  end
  return result
end

local function testBuildsDynamicCategoriesAndCounts()
  local model = BrowserModel.build(entries(), {}, { category = "boss_routes", selectedIndex = 1, scrollOffset = 1 }, 10)
  assertEqual(model.categories[1].id, "boss_routes", "boss category should be first")
  assertEqual(model.categories[1].count, 18, "boss count must derive from live entries")
  assertEqual(model.categories[2].id, "item_unlocks", "item unlock category should follow")
end

local function testKeepsSelectionInsideVisibleWindow()
  local model = BrowserModel.build(entries(), {}, { category = "boss_routes", selectedIndex = 14, scrollOffset = 1 }, 10)
  assertEqual(model.scrollOffset, 5, "selected row 14 must be visible in a ten-row window")
  assertEqual(model.rows[10].absoluteIndex, 14, "last visible row should be selected row")
end

local function testBuildsSelectedGoalDetails()
  local model = BrowserModel.build(entries(), {}, { category = "boss_routes", selectedIndex = 1 }, 10)
  assertEqual(model.details.name, "Boss 01", "sorted selected goal name should be readable")
  assertTrue(model.details.statusLabel ~= nil, "details must expose a status label")
end

local tests = {
  testBuildsDynamicCategoriesAndCounts,
  testKeepsSelectionInsideVisibleWindow,
  testBuildsSelectedGoalDetails
}

for index, test in ipairs(tests) do test(); print("navigation ok " .. index) end
print(#tests .. " navigation UI tests passed")
```

- [ ] **Step 3: Run the test and verify RED**

Run:

```powershell
npm.cmd test
```

Expected: FAIL in `tests/navigation_ui.lua` because `runcompass.browser_model` does not exist.

- [ ] **Step 4: Add deterministic browser helpers**

Append to `runcompass/browser.lua` before `return Browser`:

```lua
local STATUS_LABELS = {
  routable = "Eligible",
  locked = "Locked",
  already_unlocked = "Completed",
  instructional_only = "Instructional",
  catalog_update_required = "Update required",
  unavailable_this_run = "Unavailable"
}

function Browser.category(entry)
  if entry.kind == "boss" then return "boss_routes" end
  if entry.completionMark then return "completion_marks" end
  if entry.kind == "collectible" and entry.unlockMethod ~= "donation" and entry.unlockMethod ~= "special" then
    return "item_unlocks"
  end
  return "special"
end

function Browser.statusLabel(status)
  return STATUS_LABELS[status] or tostring(status or "Unknown")
end
```

- [ ] **Step 5: Implement the browser view model**

Create `runcompass/browser_model.lua`:

```lua
local Browser = require("runcompass.browser")
local Goals = require("runcompass.goals")

local BrowserModel = {}

local CATEGORY_ORDER = {
  { id = "boss_routes", label = "Boss Routes" },
  { id = "item_unlocks", label = "Item Unlocks" },
  { id = "completion_marks", label = "Completion Marks" },
  { id = "special", label = "Special / Other" }
}

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function categorized(entries, snapshot, filters)
  local result = {}
  for _, category in ipairs(CATEGORY_ORDER) do result[category.id] = {} end
  for _, entry in ipairs(entries or {}) do
    local resolved = Goals.resolve(entry, snapshot or {})
    for _, visible in ipairs(Browser.filter({ resolved }, filters or {})) do
      local category = Browser.category(visible)
      result[category][#result[category] + 1] = visible
    end
  end
  for _, values in pairs(result) do
    table.sort(values, function(left, right)
      local a, b = string.lower(left.name or ""), string.lower(right.name or "")
      if a == b then return tostring(left.id) < tostring(right.id) end
      return a < b
    end)
  end
  return result
end

local function details(entry)
  if not entry then return { name = "No matching goals", statusLabel = "Unavailable" } end
  local value = {
    id = entry.id,
    name = entry.name or tostring(entry.id),
    kind = entry.kind,
    status = entry.status,
    statusLabel = Browser.statusLabel(entry.status),
    requiredCharacterToken = entry.requiredCharacterToken,
    requiredDifficulty = entry.requiredDifficulty,
    unlockMethod = entry.unlockMethod or entry.displayRule,
    completionMark = entry.completionMark,
    prerequisites = entry.prerequisites or {},
    supportTier = entry.supportTier or "base",
    eligibility = entry.eligibility,
    currentRunStatus = entry.status
  }
  value.lines = {
    "Status: " .. value.statusLabel,
    "Character: " .. tostring(value.requiredCharacterToken or "Any"),
    "Difficulty: " .. tostring(value.requiredDifficulty or "Normal / Hard"),
    "Method: " .. tostring(value.unlockMethod or (value.kind == "boss" and "Boss route" or "Vanilla unlock")),
    "Support: " .. string.upper(value.supportTier),
    "Current run: " .. Browser.statusLabel(value.currentRunStatus)
  }
  for _, prerequisite in ipairs(value.prerequisites) do
    value.lines[#value.lines + 1] = "Requires: " .. tostring(prerequisite)
  end
  return value
end

function BrowserModel.build(entries, snapshot, state, pageSize)
  state, pageSize = state or {}, pageSize or 10
  local groups = categorized(entries, snapshot, state.filters or state)
  local categories = {}
  for _, category in ipairs(CATEGORY_ORDER) do
    categories[#categories + 1] = { id = category.id, label = category.label, count = #groups[category.id] }
  end
  local categoryId = state.category or "boss_routes"
  if not groups[categoryId] then categoryId = "boss_routes" end
  local goals = groups[categoryId]
  local selectedIndex = #goals == 0 and 1 or clamp(tonumber(state.selectedIndex) or 1, 1, #goals)
  local maximumOffset = math.max(1, #goals - pageSize + 1)
  local scrollOffset = clamp(tonumber(state.scrollOffset) or 1, 1, maximumOffset)
  if selectedIndex < scrollOffset then scrollOffset = selectedIndex end
  if selectedIndex > scrollOffset + pageSize - 1 then scrollOffset = selectedIndex - pageSize + 1 end
  local rows = {}
  for absoluteIndex = scrollOffset, math.min(#goals, scrollOffset + pageSize - 1) do
    local entry = goals[absoluteIndex]
    rows[#rows + 1] = {
      absoluteIndex = absoluteIndex,
      id = entry.id,
      name = entry.name,
      status = entry.status,
      statusLabel = Browser.statusLabel(entry.status),
      selected = absoluteIndex == selectedIndex,
      entry = entry
    }
  end
  return {
    categories = categories,
    activeCategory = categoryId,
    goals = goals,
    rows = rows,
    selectedIndex = selectedIndex,
    scrollOffset = scrollOffset,
    details = details(goals[selectedIndex]),
    resultCount = #goals,
    snapshot = snapshot
  }
end

return BrowserModel
```

- [ ] **Step 6: Run the suite and verify GREEN**

Run:

```powershell
npm.cmd test
```

Expected: all existing suites pass and `3 navigation UI tests passed`.

- [ ] **Step 7: Commit**

```powershell
git add package.json runcompass/browser.lua runcompass/browser_model.lua tests/navigation_ui.lua tests/guidance.lua
git commit -m "feat: add dynamic goal browser model"
```

## Task 2: Implement Three-Pane Keyboard and Controller Navigation

**Files:**

- Modify: `runcompass/ui.lua`
- Modify: `runcompass/strings.lua`
- Modify: `tests/navigation_ui.lua`

- [ ] **Step 1: Add failing pane-navigation tests**

Append to `tests/navigation_ui.lua` before the `tests` table and add all four functions to the table:

```lua
local UI = require("runcompass.ui")

local function browserUi()
  local triggered
  local selected
  local ui = UI.new({
    input = {
      IsButtonTriggered = function(code) return code == triggered end,
      IsButtonPressed = function() return false end
    },
    keyboard = {
      KEY_UP = 100, KEY_DOWN = 101, KEY_LEFT = 102, KEY_RIGHT = 103,
      KEY_ENTER = 104, KEY_ESCAPE = 105, KEY_TAB = 106, KEY_S = 107,
      KEY_L = 108, KEY_BACKSPACE = 109, KEY_A = 65, KEY_Z = 90,
      KEY_SPACE = 110, KEY_MINUS = 111, KEY_APOSTROPHE = 112,
      KEY_COMMA = 113, KEY_PERIOD = 114, KEY_SLASH = 115
    },
    controller = {
      DPAD_UP = 1, DPAD_DOWN = 2, DPAD_LEFT = 3, DPAD_RIGHT = 4,
      BUTTON_A = 5, BUTTON_B = 6, BUTTON_X = 7, BUTTON_Y = 8,
      LEFT_SHOULDER = 9, RIGHT_SHOULDER = 10
    },
    state = {
      bindings = { keyboardGoal = 117, keyboardToggle = 118, controllerGoal = 20, controllerToggle = 21 },
      browser = { category = "boss_routes", kind = "all", status = "all" }
    },
    entries = entries(),
    onGoalSelected = function(goal) selected = goal end
  })
  ui.open = true
  return ui, function(code) triggered = code; ui:input(); triggered = nil end, function() return selected end
end

local function testControllerShoulderChangesCategory()
  local ui, press = browserUi()
  press(10)
  assertEqual(ui.browserState.category, "item_unlocks", "RB should advance the active category")
  press(9)
  assertEqual(ui.browserState.category, "boss_routes", "LB should restore the previous category")
end

local function testControllerSelectionUsesScrolledAbsoluteRow()
  local ui, press, selected = browserUi()
  for _ = 1, 13 do press(2) end
  press(5)
  assertEqual(selected().name, "Boss 14", "A must select the highlighted absolute row")
end

local function testDpadMovesWithinFocusedPane()
  local ui, press = browserUi()
  press(3)
  assertEqual(ui.browserState.focusedPane, "categories", "D-pad left should focus categories")
  press(2)
  assertEqual(ui.browserState.category, "item_unlocks", "D-pad down should move inside the category pane")
  press(4)
  assertEqual(ui.browserState.focusedPane, "goals", "D-pad right should return focus to goals")
end

local function testKeyboardSearchAcceptsSpacesAndPunctuation()
  local ui, press = browserUi()
  ui.query = "King"
  press(110)
  press(112)
  assertEqual(ui.query, "King '", "search should preserve spaces and apostrophes")
end
```

- [ ] **Step 2: Run the navigation suite and verify RED**

Run:

```powershell
npx fengari tests/navigation_ui.lua
```

Expected: FAIL because `UI.browserState` and shoulder navigation do not exist.

- [ ] **Step 3: Add browser state and model refresh to UI**

At the top of `runcompass/ui.lua`:

```lua
local BrowserModel = require("runcompass.browser_model")
```

Replace `UI.new` with:

```lua
function UI.new(env)
  local saved = env.state and env.state.browser or {}
  return setmetatable({
    env = env,
    open = false,
    query = "",
    mcmNoticeShown = false,
    browserState = {
      category = saved.category or "boss_routes",
      focusedPane = "goals",
      selectedIndex = 1,
      scrollOffset = 1,
      detailOffset = 1,
      filters = {
        query = "",
        kind = saved.kind or "all",
        status = saved.status or "all",
        letter = saved.alphabet or "all",
        character = saved.character or "all",
        unlockMethod = saved.unlockMethod or "all",
        completionMark = saved.completionMark or "all"
      }
    }
  }, UI)
end

function UI:browserModel()
  self.browserState.filters.query = self.query
  return BrowserModel.build(self.env.entries, self.env.snapshot and self.env.snapshot() or {}, self.browserState, 10)
end

function UI:changeCategory(delta)
  local model = self:browserModel()
  local current = 1
  for index, category in ipairs(model.categories) do
    if category.id == self.browserState.category then current = index end
  end
  local nextIndex = ((current - 1 + delta) % #model.categories) + 1
  self.browserState.category = model.categories[nextIndex].id
  self.browserState.selectedIndex = 1
  self.browserState.scrollOffset = 1
  if self.env.state and self.env.state.browser then self.env.state.browser.category = self.browserState.category end
end
```

- [ ] **Step 4: Replace flat-list input with absolute-row navigation**

In `UI:input`, build `local model = self:browserModel()` after the open guard. Replace Up/Down and selection behavior with:

```lua
local function moveGoal(delta)
  self.browserState.selectedIndex = math.max(1, math.min(model.resultCount, self.browserState.selectedIndex + delta))
  local refreshed = self:browserModel()
  self.browserState.scrollOffset = refreshed.scrollOffset
  self.browserState.detailOffset = 1
end

local function moveVertical(delta)
  if self.browserState.focusedPane == "categories" then
    self:changeCategory(delta)
  elseif self.browserState.focusedPane == "details" then
    local maximum = math.max(1, #(model.details.lines or {}) - 5)
    self.browserState.detailOffset = math.max(1, math.min(maximum, self.browserState.detailOffset + delta))
  else
    moveGoal(delta)
  end
end

local function movePane(delta)
  local panes = { "categories", "goals", "details" }
  local current = 2
  for index, pane in ipairs(panes) do if pane == self.browserState.focusedPane then current = index end end
  self.browserState.focusedPane = panes[math.max(1, math.min(#panes, current + delta))]
end

if pressed(keyboard.KEY_UP) or (controller and pressed(controller.DPAD_UP)) then moveVertical(-1); return end
if pressed(keyboard.KEY_DOWN) or (controller and pressed(controller.DPAD_DOWN)) then moveVertical(1); return end
if controller and pressed(controller.LEFT_SHOULDER) then self:changeCategory(-1); return end
if controller and pressed(controller.RIGHT_SHOULDER) then self:changeCategory(1); return end
if pressed(keyboard.KEY_LEFT) or (controller and pressed(controller.DPAD_LEFT)) then movePane(-1); return end
if pressed(keyboard.KEY_RIGHT) or (controller and pressed(controller.DPAD_RIGHT)) then movePane(1); return end
if pressed(keyboard.KEY_ENTER) or (controller and pressed(controller.BUTTON_A)) then
  local selected = model.goals[self.browserState.selectedIndex]
  if selected and self.env.onGoalSelected then self.env.onGoalSelected(selected) end
  self.open = false
  return
end
if pressed(keyboard.KEY_ESCAPE) or (controller and pressed(controller.BUTTON_B)) then self.open = false; return end
```

Keep X/kind and Y/status cycling, storing values under `self.browserState.filters`. Replace search editing with:

```lua
if pressed(keyboard.KEY_BACKSPACE) then self.query = string.sub(self.query, 1, -2); return end
for code = keyboard.KEY_A, keyboard.KEY_Z do
  if pressed(code) then self.query = self.query .. string.char(code); return end
end
local punctuation = {
  [keyboard.KEY_SPACE] = " ",
  [keyboard.KEY_MINUS] = "-",
  [keyboard.KEY_APOSTROPHE] = "'",
  [keyboard.KEY_COMMA] = ",",
  [keyboard.KEY_PERIOD] = ".",
  [keyboard.KEY_SLASH] = "/"
}
for code, character in pairs(punctuation) do
  if code and pressed(code) then self.query = self.query .. character; return end
end
```

- [ ] **Step 5: Add browser strings**

Extend `runcompass/strings.lua`:

```lua
browser = {
  title = "Run Compass",
  search = "Search: %s",
  empty = "No matching goals",
  eligible = "ELIGIBLE",
  unavailable = "UNAVAILABLE",
  completed = "COMPLETED",
  categoryControls = "LB/RB Category",
  filterControls = "X Filter  Y Status",
  selectControls = "A Select  B Close",
  prerequisites = "Prerequisites",
  supportTier = "Support: %s",
  currentRun = "Current run: %s",
  mcmNotice = "Install Mod Config Menu for bindings and HUD settings"
}
```

- [ ] **Step 6: Render the approved three-pane browser**

Add focused render helpers to `runcompass/ui.lua`:

```lua
local function renderText(isaac, text, x, y, scale, color)
  color = color or { 1, 1, 1, 1 }
  isaac.RenderText(text, x, y, scale or 1, color[1], color[2], color[3], color[4])
end

function UI:renderBrowser()
  local isaac, model = self.env.isaac, self:browserModel()
  local leftX, middleX, rightX, top = 32, 190, 430, 34
  renderText(isaac, Strings.get("browser.title"), leftX, 18, 1, { 1, 0.84, 0.35, 1 })
  for index, category in ipairs(model.categories) do
    local active = category.id == model.activeCategory
    renderText(isaac, (active and "> " or "  ") .. category.label .. " (" .. category.count .. ")", leftX, top + index * 16, 0.8, active and { 1, 0.84, 0.35, 1 } or nil)
  end
  for rowIndex, row in ipairs(model.rows) do
    local prefix = row.selected and "> " or "  "
    renderText(isaac, prefix .. row.name, middleX, top + rowIndex * 14, 0.75, row.selected and { 1, 1, 1, 1 } or { 0.75, 0.7, 0.62, 1 })
    renderText(isaac, row.statusLabel, middleX + 155, top + rowIndex * 14, 0.55, { 0.55, 0.85, 0.65, 1 })
  end
  local detail = model.details
  renderText(isaac, detail.name, rightX, top + 14, 0.9, { 1, 0.84, 0.35, 1 })
  local detailOffset = self.browserState.detailOffset or 1
  for index = detailOffset, math.min(#(detail.lines or {}), detailOffset + 5) do
    renderText(isaac, detail.lines[index], rightX, top + 20 + (index - detailOffset + 1) * 16, 0.65)
  end
  renderText(isaac, Strings.get("browser.categoryControls"), leftX, 210, 0.6)
  renderText(isaac, Strings.get("browser.filterControls"), middleX, 210, 0.6)
  renderText(isaac, Strings.get("browser.selectControls"), rightX, 210, 0.6)
end
```

Call `self:renderBrowser()` and return when `self.open`.

- [ ] **Step 7: Run tests and verify GREEN**

Run:

```powershell
npm.cmd test
```

Expected: all suites pass; navigation suite reports seven tests.

- [ ] **Step 8: Commit**

```powershell
git add runcompass/ui.lua runcompass/strings.lua tests/navigation_ui.lua
git commit -m "feat: add three-pane goal navigation"
```

## Task 3: Show Goal Details and Human-Readable HUD Targets

**Files:**

- Modify: `main.lua`
- Modify: `runcompass/ui.lua`
- Modify: `runcompass/browser_model.lua`
- Modify: `tests/navigation_ui.lua`

- [ ] **Step 1: Add failing readable-target and details tests**

Append to `tests/navigation_ui.lua`:

```lua
local function testHudUsesSelectedGoalNameInsteadOfInternalId()
  local rendered = {}
  local ui = UI.new({
    isaac = { RenderText = function(text) rendered[#rendered + 1] = text end },
    game = {},
    state = { selectedGoalId = "boss.mega_satan", hud = { visible = true, scale = 1, x = 0, y = 0 }, decision = {}, bindings = {} },
    entries = entries(),
    getSelectedGoal = function() return { id = "boss.mega_satan", name = "Mega Satan" } end
  })
  ui:render({ currentRoomClear = true }, { status = "explore", steps = {}, confidence = "low", capabilityTier = "enhanced" })
  local joined = table.concat(rendered, "\n")
  assertTrue(string.find(joined, "Mega Satan", 1, true) ~= nil, "HUD should show the catalog name")
  assertTrue(string.find(joined, "boss.mega_satan", 1, true) == nil, "HUD should hide internal IDs")
end

local function testDetailsExposePrerequisiteChain()
  local source = entries()
  source[1].prerequisites = { "achievement.1", "achievement.2" }
  local model = BrowserModel.build(source, {}, { category = "boss_routes", selectedIndex = 18 }, 10)
  assertEqual(#model.details.prerequisites, 2, "details should preserve prerequisite chains")
end
```

Add both functions to `tests`.

- [ ] **Step 2: Run the navigation suite and verify RED**

Run:

```powershell
npx fengari tests/navigation_ui.lua
```

Expected: FAIL because HUD rendering still uses `state.selectedGoalId`.

- [ ] **Step 3: Inject selected-goal lookup from main**

In `main.lua`, add to `UI.new`:

```lua
getSelectedGoal = function()
  return catalog and catalog:get(state.selectedGoalId) or nil
end,
snapshot = function()
  return runtime and runtime.snapshot or nil
end,
spriteFactory = rawget(_G, "Sprite")
```

In `onGoalSelected`, keep persistence ID-only:

```lua
state.selectedGoalId = entry.id
controller:onEvent("TARGET_CHANGED")
```

- [ ] **Step 4: Render the catalog name**

In `UI:render`:

```lua
local selectedGoal = self.env.getSelectedGoal and self.env.getSelectedGoal() or nil
local selectedName = selectedGoal and selectedGoal.name or tostring(self.env.state.selectedGoalId or "Delirium")
isaac.RenderText(Strings.get("hud.target", selectedName), cardX, cardY, scale, 0.8, 0.9, 1)
```

Do not add `selectedGoalName` to save data.

- [ ] **Step 5: Run tests and verify GREEN**

Run:

```powershell
npm.cmd test
```

Expected: all suites pass and both target/detail regressions pass.

- [ ] **Step 6: Commit**

```powershell
git add main.lua runcompass/ui.lua runcompass/browser_model.lua tests/navigation_ui.lua
git commit -m "feat: show readable goal details"
```

## Task 4: Rank Revealed Frontiers Instead of Selecting the First Door

**Files:**

- Create: `runcompass/frontier.lua`
- Replace: `tests/guidance.lua`
- Modify: `runcompass/planner.lua`
- Modify: `tests/performance.lua`

- [ ] **Step 1: Write failing frontier-ranking tests**

Replace `tests/guidance.lua` with:

```lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local Frontier = require("runcompass.frontier")
local Planner = require("runcompass.planner")

local function assertEqual(actual, expected, message)
  if actual ~= expected then error((message or "values differ") .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")") end
end

local function assertTrue(value, message)
  if not value then error(message or "expected truthy value") end
end

local function snapshot()
  return {
    currentRoom = 1,
    currentRoomClear = true,
    mode = { kind = "normal", difficulty = "normal", progressionAllowed = true },
    player = { health = 6, maxHealth = 6, keys = 2, bombs = 1, coins = 5, resources = { keys = 2, bombs = 1, coins = 5 } },
    visibility = { curseBlind = false, curseLost = false },
    capabilities = { tier = "enhanced" },
    rooms = {
      { id = 1, kind = "normal", visited = true, clear = true, doors = { { slot = 0, to = 2 }, { slot = 2, to = 3 } } },
      { id = 2, kind = "normal", visited = false, clear = false, doors = { { slot = 2, to = 1 } }, pickups = {} },
      { id = 3, kind = "treasure", visited = false, clear = false, doors = { { slot = 0, to = 1 } }, pickups = { { id = 100, visible = true, quality = 4 } } }
    },
    visibleChoices = {}
  }
end

local function testRanksKnownTreasureFrontierAboveNormalFrontier()
  local candidate = Frontier.best(snapshot(), { id = "boss.mega_satan", destinationRooms = {}, frontier = true })
  assertEqual(candidate.doorSlot, 2, "known treasure value should beat iteration order")
  assertEqual(candidate.nextRoomId, 3, "candidate should identify the ranked frontier")
end

local function testPlannerExploreUsesRankedFrontier()
  local result = Planner.plan(snapshot(), { id = "boss.mega_satan", destinationRooms = {}, frontier = true })
  assertEqual(result.status, "explore", "unknown target branch should remain exploratory")
  assertEqual(result.nextDoorSlot, 2, "planner must expose the ranked exact door")
  assertTrue(result.reasonCodes.ranked_frontier, "explanation should identify ranked frontier selection")
end

local tests = {
  testRanksKnownTreasureFrontierAboveNormalFrontier,
  testPlannerExploreUsesRankedFrontier
}

for index, test in ipairs(tests) do test(); print("guidance ok " .. index) end
print(#tests .. " guidance tests passed")
```

- [ ] **Step 2: Run the guidance suite and verify RED**

Run:

```powershell
npx fengari tests/guidance.lua
```

Expected: FAIL because `runcompass.frontier` does not exist.

- [ ] **Step 3: Implement frontier candidate ranking**

Create `runcompass/frontier.lua`:

```lua
local Valuation = require("runcompass.valuation")

local Frontier = {}

local function roomMap(rooms)
  local result = {}
  for _, room in ipairs(rooms or {}) do result[room.id] = room end
  return result
end

local function visible(room, visibility)
  return room and not room.hidden and not room.secret and not (visibility.curseLost and not room.visited)
end

local function firstDoor(current, path)
  for _, door in ipairs(current.doors or {}) do
    if path[2] == door.to then return door.slot end
  end
end

local function revealedPaths(snapshot, map)
  local start = snapshot.currentRoom
  local queue, head = { start }, 1
  local parent, seen = {}, { [start] = true }
  while head <= #queue do
    local roomId = queue[head]
    head = head + 1
    for _, door in ipairs(map[roomId] and map[roomId].doors or {}) do
      if not seen[door.to] and visible(map[door.to], snapshot.visibility or {}) then
        seen[door.to] = true
        parent[door.to] = roomId
        queue[#queue + 1] = door.to
      end
    end
  end
  local function pathTo(destination)
    if not seen[destination] then return nil end
    local reversed, cursor = { destination }, destination
    while cursor ~= start do
      cursor = parent[cursor]
      if cursor == nil then return nil end
      reversed[#reversed + 1] = cursor
    end
    local path = {}
    for index = #reversed, 1, -1 do path[#path + 1] = reversed[index] end
    return path
  end
  return pathTo
end

function Frontier.candidates(snapshot, goal)
  local map, current = roomMap(snapshot.rooms), nil
  current = map[snapshot.currentRoom]
  if not current then return {} end
  local result, seen, pathTo = {}, {}, revealedPaths(snapshot, map)
  for _, room in ipairs(snapshot.rooms or {}) do
    if room.id ~= snapshot.currentRoom and visible(room, snapshot.visibility or {}) and (not room.visited or room.kind == "treasure" or room.kind == "shop") then
      local path = pathTo(room.id)
      if path and #path > 1 then
        local slot = firstDoor(current, path)
        if slot ~= nil and not seen[room.id] then
          seen[room.id] = true
          result[#result + 1] = {
            doorSlot = slot,
            nextRoomId = room.id,
            path = path,
            roomKind = room.kind,
            evaluation = Valuation.evaluate(snapshot, path, goal),
            reasonCodes = {
              ranked_frontier = true,
              treasure_detour = room.kind == "treasure",
              shop_detour = room.kind == "shop"
            }
          }
        end
      end
    end
  end
  return result
end

function Frontier.best(snapshot, goal)
  local candidates = Frontier.candidates(snapshot, goal)
  table.sort(candidates, function(left, right)
    local compared = Valuation.compare(left.evaluation, right.evaluation)
    if compared ~= 0 then return compared > 0 end
    if #left.path ~= #right.path then return #left.path < #right.path end
    return left.nextRoomId < right.nextRoomId
  end)
  return candidates[1]
end

return Frontier
```

- [ ] **Step 4: Replace planner's first-door frontier branch**

At the top of `runcompass/planner.lua`:

```lua
local Frontier = require("runcompass.frontier")
```

Replace the `#destinations == 0 and goal.frontier` block with:

```lua
if #destinations == 0 and goal.frontier then
  local candidate = Frontier.best(snapshot, goal)
  if candidate then
    local step = candidate.roomKind == "treasure" and "Take the treasure-room detour"
      or candidate.roomKind == "shop" and "Check the worthwhile shop route"
      or "Explore the best revealed frontier"
    return {
      status = "explore",
      nextDoorSlot = candidate.doorSlot,
      steps = { step, "Replan when the target branch appears" },
      score = candidate.evaluation.utility,
      scoreVector = candidate.evaluation,
      reasonCodes = candidate.reasonCodes,
      confidence = "low",
      capabilityTier = capabilityTier(snapshot)
    }
  end
end
```

- [ ] **Step 5: Run tests and verify GREEN**

Run:

```powershell
npm.cmd test
```

Expected: all suites pass and `2 guidance tests passed`.

- [ ] **Step 6: Add and run the frontier performance gate**

Append to `tests/performance.lua`:

```lua
local Frontier = require("runcompass.frontier")
local frontierRooms = {}
for id = 1, 48 do
  local doors = {}
  if id > 1 then doors[#doors + 1] = { slot = 0, to = id - 1 } end
  if id < 48 then doors[#doors + 1] = { slot = 2, to = id + 1 } end
  frontierRooms[#frontierRooms + 1] = {
    id = id,
    visited = id == 1,
    hidden = false,
    kind = id == 48 and "treasure" or "normal",
    doors = doors,
    pickups = id == 48 and { { visible = true, quality = 4 } } or {}
  }
end
local frontierSnapshot = {
  currentRoom = 1,
  visibility = {},
  player = { keys = 6, bombs = 6, coins = 20, health = 6, maxHealth = 6 },
  rooms = frontierRooms
}
local frontierStart = os.clock()
local frontierCandidate = Frontier.best(frontierSnapshot, { destinationRooms = {}, frontier = true })
local frontierElapsed = os.clock() - frontierStart
assert(frontierCandidate and frontierCandidate.doorSlot ~= nil, "frontier benchmark should produce an actionable door")
assert(frontierElapsed < 0.012, "frontier ranking exceeded 12 ms: " .. tostring(frontierElapsed))
print(string.format("performance frontier %.4fs", frontierElapsed))
```

Run:

```powershell
npx fengari tests/performance.lua
```

Expected: both planner and frontier benchmarks pass; frontier reports below `0.0120s`.

- [ ] **Step 7: Commit**

```powershell
git add runcompass/frontier.lua runcompass/planner.lua tests/guidance.lua tests/performance.lua
git commit -m "feat: rank revealed route frontiers"
```

## Task 5: Attach Build Decisions to Every Actionable Recommendation

**Files:**

- Create: `runcompass/recommendation.lua`
- Modify: `runcompass/planner.lua`
- Modify: `tests/guidance.lua`

- [ ] **Step 1: Add failing explore-decision tests**

Append to `tests/guidance.lua`:

```lua
local function testExploreRecommendationIncludesVisibleItemDecision()
  local value = snapshot()
  value.currentRoom = 3
  value.rooms[3].visited = true
  value.rooms[3].clear = true
  value.rooms[3].doors = { { slot = 0, to = 1 } }
  value.visibleChoices = {
    {
      id = "3:collectible:100",
      roomId = 3,
      kind = "collectible",
      position = { x = 320, y = 280 },
      observedIdentity = { id = 100, name = "Test Relic", quality = 4 },
      eligibleActors = { "primary" },
      confidence = "high"
    }
  }
  local models = {
    featureSummary = function() return { effects = {}, tags = {} } end,
    evaluate = function()
      return { effects = { offense = 4 }, reasonCodes = { character_synergy = true }, warnings = {}, ruleIds = {}, confidence = "high" }
    end
  }
  local result = Planner.plan(value, { id = "boss.mega_satan", destinationRooms = {}, frontier = true }, nil, models)
  assertTrue(result.decision and result.decision.primary, "explore state must retain visible choices")
  assertEqual(result.decision.primary.action, "take", "valuable visible pedestal should recommend TAKE")
  assertEqual(result.decision.primary.position.x, 320, "entity marker position must survive finalization")
end

local function testExploreHysteresisKeepsValidEquivalentDoor()
  local value = snapshot()
  local previous = {
    status = "explore",
    nextDoorSlot = 0,
    score = 1000,
    steps = { "Keep stable frontier" },
    reasonCodes = { ranked_frontier = true }
  }
  local result = Planner.plan(value, { id = "boss.mega_satan", destinationRooms = {}, frontier = true }, previous)
  assertEqual(result.nextDoorSlot, 0, "valid equivalent-risk frontier should retain the previous door")
end
```

Add both tests to `tests`.

- [ ] **Step 2: Run the guidance suite and verify RED**

Run:

```powershell
npx fengari tests/guidance.lua
```

Expected: FAIL because the `explore` return occurs before `ChoiceEngine.evaluate`.

- [ ] **Step 3: Implement the shared finalizer**

Create `runcompass/recommendation.lua`:

```lua
local ChoiceEngine = require("runcompass.choice_engine")

local Recommendation = {}

local ACTIONABLE = { ok = true, explore = true }

function Recommendation.finalize(snapshot, goal, recommendation, milestone, decisionModels)
  recommendation.reasonCodes = recommendation.reasonCodes or {}
  for code, enabled in pairs(milestone and milestone.reasonCodes or {}) do
    recommendation.reasonCodes[code] = enabled
  end
  if milestone and next(milestone.requiredItems or {}) then
    recommendation.reasonCodes.required_quest_items = true
  end
  if not ACTIONABLE[recommendation.status] then return recommendation end
  local visibleChoices = {}
  for _, choice in ipairs(snapshot.visibleChoices or {}) do
    if choice.roomId == snapshot.currentRoom then visibleChoices[#visibleChoices + 1] = choice end
  end
  if #visibleChoices > 0 then
    recommendation.decision = ChoiceEngine.evaluate(
      snapshot,
      visibleChoices,
      goal,
      decisionModels or snapshot.decisionModels,
      snapshot.eid
    )
  end
  return recommendation
end

return Recommendation
```

- [ ] **Step 4: Route actionable planner returns through the finalizer**

At the top of `runcompass/planner.lua`:

```lua
local Recommendation = require("runcompass.recommendation")
```

For the ranked-frontier branch:

```lua
local recommendation = {
  status = "explore",
  nextDoorSlot = candidate.doorSlot,
  steps = { step, "Replan when the target branch appears" },
  score = candidate.evaluation.utility,
  scoreVector = candidate.evaluation,
  reasonCodes = candidate.reasonCodes,
  confidence = "low",
  capabilityTier = capabilityTier(snapshot)
}
return Recommendation.finalize(snapshot, goal, recommendation, milestone, decisionModels)
```

Replace the manual choice attachment near the end of `Planner.plan` with:

```lua
recommendation = Recommendation.finalize(snapshot, goal, recommendation, milestone, decisionModels)
if keepPrevious(snapshot, previous, recommendation) then return previous end
return recommendation
```

Remove the direct `ChoiceEngine` require and the duplicated visible-choice loop from `planner.lua`.

Allow the existing hysteresis helper to retain either actionable status:

```lua
local ACTIONABLE_STATUS = { ok = true, explore = true }

local function previousChoiceStillExists(snapshot, previous)
  local primary = previous.decision and previous.decision.primary
  if not primary or not primary.choiceId then return true end
  for _, choice in ipairs(snapshot.visibleChoices or {}) do
    if choice.roomId == snapshot.currentRoom and choice.id == primary.choiceId then return true end
  end
  return false
end

local function decisionStillEquivalent(previous, recommendation)
  local old = previous.decision and previous.decision.primary
  local new = recommendation.decision and recommendation.decision.primary
  if old == nil and new == nil then return true end
  if old == nil or new == nil then return false end
  return old.choiceId == new.choiceId
    and old.action == new.action
    and old.actorToken == new.actorToken
    and (old.scoreVector and old.scoreVector.feasible) == (new.scoreVector and new.scoreVector.feasible)
    and (old.scoreVector and old.scoreVector.resourceMargin) == (new.scoreVector and new.scoreVector.resourceMargin)
end

local function keepPrevious(snapshot, previous, recommendation)
  if not previous or not ACTIONABLE_STATUS[previous.status] or not ACTIONABLE_STATUS[recommendation.status]
      or not doorExists(snapshot, previous.nextDoorSlot)
      or not previousChoiceStillExists(snapshot, previous)
      or not decisionStillEquivalent(previous, recommendation) then return false end
  if previous.nextDoorSlot == recommendation.nextDoorSlot then return true end
  local oldScore, newScore = tonumber(previous.score) or 0, tonumber(recommendation.score) or 0
  if newScore <= oldScore then return true end
  return (newScore - oldScore) < math.max(math.abs(oldScore), 1) * 0.10
end
```

After finalizing the ranked-frontier recommendation:

```lua
recommendation = Recommendation.finalize(snapshot, goal, recommendation, milestone, decisionModels)
if keepPrevious(snapshot, previous, recommendation) then return previous end
return recommendation
```

- [ ] **Step 5: Run tests and verify GREEN**

Run:

```powershell
npm.cmd test
```

Expected: all suites pass; the explore result contains a TAKE decision and entity coordinates.

- [ ] **Step 6: Commit**

```powershell
git add runcompass/recommendation.lua runcompass/planner.lua tests/guidance.lua
git commit -m "feat: evaluate choices during exploration"
```

## Task 6: Build the Compact HUD and Correct Live Markers

**Files:**

- Create: `runcompass/hud.lua`
- Create: `gfx/ui/guidance-markers.png`
- Create: `gfx/ui/guidance-markers.anm2`
- Modify: `runcompass/ui.lua`
- Modify: `runcompass/presentation.lua`
- Modify: `runcompass/strings.lua`
- Modify: `tests/navigation_ui.lua`
- Modify: `tests/guidance.lua`

- [ ] **Step 1: Write failing compact-view and door-position tests**

Append to `tests/guidance.lua`:

```lua
local Hud = require("runcompass.hud")

local function testDoorPositionUsesGameRoom()
  local requestedSlot
  local game = {
    GetRoom = function()
      return {
        GetDoorSlotPosition = function(_, slot)
          requestedSlot = slot
          return { X = 600, Y = 280 }
        end
      }
    end
  }
  local position = Hud.doorPosition(game, 2)
  assertEqual(requestedSlot, 2, "HUD must request the recommended slot from Game:GetRoom")
  assertEqual(position.x, 600, "door marker should use the live X coordinate")
end

local function testCompactCardUsesStrongestReasonAndWarning()
  local view = Hud.view({
    status = "ok",
    steps = { "Take the treasure-room detour", "Long secondary text" },
    confidence = "high",
    decision = {
      primary = {
        action = "take",
        name = "Test Relic",
        reasonCodes = { owned_item_synergy = true, character_synergy = true },
        warnings = { "active_replacement_loss" },
        confidence = "high"
      }
    }
  }, "Mega Satan", false)
  assertEqual(view.target, "Mega Satan", "card should use readable target")
  assertEqual(view.action, "TAKE", "card should expose immediate action")
  assertTrue(#view.lines <= 4, "compact card must remain bounded")
  assertEqual(#view.warnings, 1, "compact card should preserve the strongest warning")
end
```

Add both tests to `tests`.

- [ ] **Step 2: Run the guidance suite and verify RED**

Run:

```powershell
npx fengari tests/guidance.lua
```

Expected: FAIL because `runcompass.hud` does not exist.

- [ ] **Step 3: Implement pure HUD view data and door lookup**

Create `runcompass/hud.lua`:

```lua
local Hud = {}

local REASON_PRIORITY = {
  "goal_resource_reserved",
  "active_replacement_loss",
  "anti_synergy",
  "transformation_threshold",
  "owned_item_synergy",
  "character_synergy",
  "ranked_frontier"
}

function Hud.strongestReason(reasonCodes)
  for _, reason in ipairs(REASON_PRIORITY) do
    if reasonCodes and reasonCodes[reason] then return reason end
  end
  if reasonCodes then
    local keys = {}
    for reason, enabled in pairs(reasonCodes) do if enabled then keys[#keys + 1] = reason end end
    table.sort(keys)
    return keys[1]
  end
end

function Hud.doorPosition(game, slot)
  if not game or slot == nil or type(game.GetRoom) ~= "function" then return nil end
  local ok, room = pcall(game.GetRoom, game)
  if not ok or not room or type(room.GetDoorSlotPosition) ~= "function" then return nil end
  local positioned, value = pcall(room.GetDoorSlotPosition, room, slot)
  if not positioned or not value then return nil end
  return { x = value.X or 0, y = value.Y or 0 }
end

function Hud.view(recommendation, targetName, expanded)
  local primary = recommendation.decision and recommendation.decision.primary or nil
  local lines = {}
  for index, step in ipairs(recommendation.steps or {}) do
    if index > (expanded and 3 or 1) then break end
    lines[#lines + 1] = step
  end
  local reason = primary and Hud.strongestReason(primary.reasonCodes) or Hud.strongestReason(recommendation.reasonCodes)
  if reason then lines[#lines + 1] = reason end
  if primary and primary.name then lines[#lines + 1] = primary.name end
  while not expanded and #lines > 4 do table.remove(lines) end
  return {
    target = targetName,
    status = recommendation.status,
    lines = lines,
    action = primary and string.upper(primary.action or "") or nil,
    choiceName = primary and primary.name or nil,
    choicePosition = primary and primary.position or nil,
    confidence = primary and primary.confidence or recommendation.confidence,
    warnings = primary and primary.warnings or {},
    nextDoorSlot = recommendation.nextDoorSlot,
    expanded = expanded == true
  }
end

return Hud
```

- [ ] **Step 4: Create original marker assets**

Create `gfx/ui/guidance-markers.png` as a transparent 128×32 RGBA spritesheet:

- Pixels 0–31: green diamond with white check for TAKE/BUY.
- Pixels 32–63: amber diamond with black exclamation for conditional/replacement advice.
- Pixels 64–95: red diamond with white cross for SKIP.
- Pixels 96–127: cyan diamond with white circular arrow for REROLL.

Create `gfx/ui/guidance-markers.anm2` with one 32×32 single-frame looping animation per crop:

```xml
<AnimatedActor>
  <Info CreatedBy="Run Compass" CreatedOn="28.07.2026" Fps="30" Version="42" />
  <Content>
    <Spritesheets>
      <Spritesheet Id="0" Path="guidance-markers.png" />
    </Spritesheets>
    <Layers>
      <Layer Id="0" Name="Marker" SpritesheetId="0" />
    </Layers>
    <Nulls />
    <Events />
  </Content>
  <Animations DefaultAnimation="Take">
    <Animation Name="Take" FrameNum="1" Loop="true">
      <RootAnimation>
        <Frame XPosition="0" YPosition="0" Delay="1" Visible="true" XScale="100" YScale="100" RedTint="255" GreenTint="255" BlueTint="255" AlphaTint="255" RedOffset="0" GreenOffset="0" BlueOffset="0" Rotation="0" Interpolated="false" />
      </RootAnimation>
      <LayerAnimations>
        <LayerAnimation LayerId="0" Visible="true">
          <Frame XPosition="0" YPosition="0" XPivot="16" YPivot="16" XCrop="0" YCrop="0" Width="32" Height="32" XScale="100" YScale="100" Delay="1" Visible="true" RedTint="255" GreenTint="255" BlueTint="255" AlphaTint="255" RedOffset="0" GreenOffset="0" BlueOffset="0" Rotation="0" Interpolated="false" />
        </LayerAnimation>
      </LayerAnimations>
    </Animation>
    <Animation Name="Caution" FrameNum="1" Loop="true">
      <RootAnimation>
        <Frame XPosition="0" YPosition="0" Delay="1" Visible="true" XScale="100" YScale="100" RedTint="255" GreenTint="255" BlueTint="255" AlphaTint="255" RedOffset="0" GreenOffset="0" BlueOffset="0" Rotation="0" Interpolated="false" />
      </RootAnimation>
      <LayerAnimations>
        <LayerAnimation LayerId="0" Visible="true">
          <Frame XPosition="0" YPosition="0" XPivot="16" YPivot="16" XCrop="32" YCrop="0" Width="32" Height="32" XScale="100" YScale="100" Delay="1" Visible="true" RedTint="255" GreenTint="255" BlueTint="255" AlphaTint="255" RedOffset="0" GreenOffset="0" BlueOffset="0" Rotation="0" Interpolated="false" />
        </LayerAnimation>
      </LayerAnimations>
    </Animation>
    <Animation Name="Skip" FrameNum="1" Loop="true">
      <RootAnimation>
        <Frame XPosition="0" YPosition="0" Delay="1" Visible="true" XScale="100" YScale="100" RedTint="255" GreenTint="255" BlueTint="255" AlphaTint="255" RedOffset="0" GreenOffset="0" BlueOffset="0" Rotation="0" Interpolated="false" />
      </RootAnimation>
      <LayerAnimations>
        <LayerAnimation LayerId="0" Visible="true">
          <Frame XPosition="0" YPosition="0" XPivot="16" YPivot="16" XCrop="64" YCrop="0" Width="32" Height="32" XScale="100" YScale="100" Delay="1" Visible="true" RedTint="255" GreenTint="255" BlueTint="255" AlphaTint="255" RedOffset="0" GreenOffset="0" BlueOffset="0" Rotation="0" Interpolated="false" />
        </LayerAnimation>
      </LayerAnimations>
    </Animation>
    <Animation Name="Reroll" FrameNum="1" Loop="true">
      <RootAnimation>
        <Frame XPosition="0" YPosition="0" Delay="1" Visible="true" XScale="100" YScale="100" RedTint="255" GreenTint="255" BlueTint="255" AlphaTint="255" RedOffset="0" GreenOffset="0" BlueOffset="0" Rotation="0" Interpolated="false" />
      </RootAnimation>
      <LayerAnimations>
        <LayerAnimation LayerId="0" Visible="true">
          <Frame XPosition="0" YPosition="0" XPivot="16" YPivot="16" XCrop="96" YCrop="0" Width="32" Height="32" XScale="100" YScale="100" Delay="1" Visible="true" RedTint="255" GreenTint="255" BlueTint="255" AlphaTint="255" RedOffset="0" GreenOffset="0" BlueOffset="0" Rotation="0" Interpolated="false" />
        </LayerAnimation>
      </LayerAnimations>
    </Animation>
  </Animations>
</AnimatedActor>
```

Each animation uses the corresponding `XCrop` value `0`, `32`, `64`, or `96`, with `Width="32"` and `Height="32"`.

- [ ] **Step 5: Load sprites once in UI**

At the top of `runcompass/ui.lua`:

```lua
local Hud = require("runcompass.hud")

local function loadSprite(factory, path, animation)
  if type(factory) ~= "function" then return nil end
  local ok, sprite = pcall(factory)
  if not ok or not sprite then return nil end
  local loaded = pcall(sprite.Load, sprite, path, true)
  if not loaded then return nil end
  pcall(sprite.Play, sprite, animation, true)
  return sprite
end
```

Replace the `UI.new` definition from Task 2 with:

```lua
function UI.new(env)
  local saved = env.state and env.state.browser or {}
  local ui = setmetatable({
    env = env,
    open = false,
    query = "",
    mcmNoticeShown = false,
    detailHeld = false,
    browserState = {
      category = saved.category or "boss_routes",
      focusedPane = "goals",
      selectedIndex = 1,
      scrollOffset = 1,
      detailOffset = 1,
      filters = {
        query = "",
        kind = saved.kind or "all",
        status = saved.status or "all",
        letter = saved.alphabet or "all",
        character = saved.character or "all",
        unlockMethod = saved.unlockMethod or "all",
        completionMark = saved.completionMark or "all"
      }
    }
  }, UI)
  ui.arrowSprite = loadSprite(env.spriteFactory, "gfx/ui/compass-arrow.anm2", "Idle")
  ui.markerSprite = loadSprite(env.spriteFactory, "gfx/ui/guidance-markers.anm2", "Take")
  return ui
end
```

- [ ] **Step 6: Render the compact persistent card and exact markers**

In `UI:render`, replace raw `Presentation.lines` rendering with:

```lua
local selectedGoal = self.env.getSelectedGoal and self.env.getSelectedGoal() or nil
local targetName = selectedGoal and selectedGoal.name or tostring(self.env.state.selectedGoalId or "Delirium")
local expanded = self.detailHeld == true
local view = Hud.view(recommendation, targetName, expanded)
local scale = self.env.state.hud.scale or 1
local cardX = 20 + (self.env.state.hud.x or 0)
local cardY = 18 + (self.env.state.hud.y or 0)
isaac.RenderText(view.target, cardX, cardY, 0.8 * scale, 1, 0.84, 0.35, 1)
for index, line in ipairs(view.lines) do
  isaac.RenderText(Presentation.label(line), cardX, cardY + index * 12, 0.7 * scale, 1, 0.92, 0.75, 1)
end
if view.action then
  isaac.RenderText(view.action, cardX, cardY + (#view.lines + 1) * 12, 0.75 * scale, 0.55, 0.9, 0.62, 1)
end
```

Render the door marker:

```lua
local doorPosition = Hud.doorPosition(self.env.game, view.nextDoorSlot)
if doorPosition then
  local rotations = { [0] = 180, [1] = -90, [2] = 0, [3] = 90, [4] = 180, [5] = -90, [6] = 0, [7] = 90 }
  if self.arrowSprite then
    self.arrowSprite.Rotation = rotations[view.nextDoorSlot] or 0
    self.arrowSprite.Scale = Vector(0.5 * scale, 0.5 * scale)
    self.arrowSprite:Render(Vector(doorPosition.x, doorPosition.y))
  else
    isaac.RenderText("→", doorPosition.x - 8, doorPosition.y - 8, 0.5 * scale, 1, 0.84, 0.2, 1)
  end
end
```

Render the action marker:

```lua
if view.choicePosition then
  local animation = view.action == "SKIP" and "Skip"
    or view.action == "REROLL" and "Reroll"
    or (view.warnings and #view.warnings > 0) and "Caution"
    or "Take"
  if self.markerSprite then
    self.markerSprite:Play(animation, true)
    self.markerSprite.Scale = Vector(0.65 * scale, 0.65 * scale)
    self.markerSprite:Render(Vector(view.choicePosition.x, view.choicePosition.y - 24))
  else
    isaac.RenderText(view.action or "◆", view.choicePosition.x - 12, view.choicePosition.y - 24, 0.45 * scale, 0.55, 0.9, 0.62, 1)
  end
end
```

- [ ] **Step 7: Add readable compact labels**

Add to `runcompass/presentation.lua`:

```lua
local LABELS = {
  ranked_frontier = "Best revealed frontier",
  treasure_detour = "Worthwhile treasure detour",
  shop_detour = "Worthwhile shop detour",
  character_synergy = "Strong for this character",
  owned_item_synergy = "Synergizes with owned items",
  anti_synergy = "Conflicts with the current build",
  transformation_threshold = "Completes or advances a transformation",
  active_replacement_loss = "Replacing the active loses stored value",
  goal_resource_reserved = "Preserve resources for the target"
}

function Presentation.label(code)
  return LABELS[code] or tostring(code or "")
end
```

- [ ] **Step 8: Run tests and verify GREEN**

Run:

```powershell
npm.cmd test
```

Expected: all suites pass; door lookup uses `Game:GetRoom`, compact lines are bounded, and target/action data are readable.

- [ ] **Step 9: Commit**

```powershell
git add runcompass/hud.lua runcompass/ui.lua runcompass/presentation.lua runcompass/strings.lua tests/navigation_ui.lua tests/guidance.lua gfx/ui/guidance-markers.png gfx/ui/guidance-markers.anm2
git commit -m "feat: render compact route and choice guidance"
```

## Task 7: Add Detail Binding, Save Migration, and Lifecycle Invalidation

**Files:**

- Modify: `runcompass/save.lua`
- Modify: `runcompass/mcm.lua`
- Modify: `runcompass/ui.lua`
- Modify: `main.lua`
- Modify: `tests/run.lua`
- Modify: `tests/navigation_ui.lua`
- Modify: `tests/guidance.lua`

- [ ] **Step 1: Write failing schema-v4 and held-detail tests**

Append to `tests/run.lua`:

```lua
local function testSaveV4AddsBrowserCategoryAndDetailBindings()
  local migrated = Save.migrate({ schemaVersion = 3, browser = { status = "locked" }, bindings = { keyboardGoal = 117 } })
  assertEqual(migrated.schemaVersion, 4, "guidance UI requires schema v4")
  assertEqual(migrated.browser.category, "boss_routes", "migration should add the default category")
  assertEqual(migrated.bindings.keyboardDetail, 119, "migration should add a detail key")
  assertEqual(migrated.bindings.controllerDetail, 11, "migration should add a detail controller button")
end
```

Append to `tests/navigation_ui.lua`:

```lua
local function testHeldDetailBindingExpandsWithoutToggling()
  local held = true
  local ui = UI.new({
    input = {
      IsButtonTriggered = function() return false end,
      IsButtonPressed = function(code) return held and code == 119 end
    },
    keyboard = {},
    controller = {},
    state = { bindings = { keyboardDetail = 119, controllerDetail = 11 }, browser = {}, hud = {}, decision = {} },
    entries = {}
  })
  ui:input()
  assertEqual(ui.detailHeld, true, "holding the detail key should expand the compact card")
  held = false
  ui:input()
  assertEqual(ui.detailHeld, false, "releasing the key should restore compact mode")
end
```

Add both tests to their suites.

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
npm.cmd test
```

Expected: FAIL because schema v4 and detail bindings do not exist.

- [ ] **Step 3: Migrate save schema to v4**

In `runcompass/save.lua`:

```lua
local CURRENT_SCHEMA = 4
```

Update defaults:

```lua
browser = {
  category = "boss_routes",
  alphabet = "all",
  kind = "all",
  status = "all",
  character = "all",
  unlockMethod = "all",
  completionMark = "all"
},
bindings = {
  keyboardGoal = 117,
  keyboardToggle = 118,
  keyboardDetail = 119,
  controllerGoal = 10,
  controllerDetail = 11,
  controllerToggle = 13
}
```

The existing default-merging loops migrate v0–v3 data without persisting cursor, scroll offset, recommendations, observations, or item decisions.

- [ ] **Step 4: Register interactive detail bindings in MCM**

In `runcompass/mcm.lua`, add:

```lua
setting("General", "Guidance details", "KEYBIND_KEYBOARD",
  function() return "Guidance details: " .. bindingName(state.bindings.keyboardDetail, false) end,
  function() return state.bindings.keyboardDetail end,
  function(value) state.bindings.keyboardDetail = value end)

setting("General", "Controller details", "KEYBIND_CONTROLLER",
  function() return "Controller details: " .. bindingName(state.bindings.controllerDetail, true) end,
  function() return state.bindings.controllerDetail end,
  function(value) state.bindings.controllerDetail = value end)
```

These use the already-correct MCM popup configuration.

- [ ] **Step 5: Read held detail state without planning**

At the beginning of `UI:input`:

```lua
local held = function(code)
  return code ~= nil and input.IsButtonPressed and input.IsButtonPressed(code, 0)
end
self.detailHeld = held(state.bindings.keyboardDetail) or held(state.bindings.controllerDetail)
```

This changes render detail only and never invalidates the route.

- [ ] **Step 6: Strengthen the runtime fingerprint**

In `main.lua`, include current-choice positions, replacement state, player stats, character/form, resources, and target:

```lua
choiceSignature[#choiceSignature + 1] = table.concat({
  tostring(choice.id),
  tostring(choice.price),
  tostring(choice.observedIdentity and choice.observedIdentity.id),
  tostring(choice.position and choice.position.x),
  tostring(choice.position and choice.position.y),
  tostring(choice.replacement and choice.replacement.id)
}, ",")
```

Add to the final `table.concat` input:

```lua
tostring(state.selectedGoalId),
tostring(player.characterToken),
tostring(player.actorToken),
tostring(player.stats and player.stats.damage),
tostring(player.stats and player.stats.fireRate),
tostring(player.stats and player.stats.speed)
```

This makes pickup, purchase, reroll, entity removal, affordability, form, and stat changes invalidate stale recommendations through the existing controller event.

- [ ] **Step 7: Add marker invalidation test**

Append to `tests/guidance.lua`:

```lua
local function testRemovedChoiceCannotLeaveStaleMarker()
  local value = snapshot()
  value.visibleChoices = {
    { id = "choice.1", roomId = 1, kind = "collectible", position = { x = 100, y = 100 }, observedIdentity = { id = 100, name = "Relic" }, eligibleActors = { "primary" } }
  }
  local first = Planner.plan(value, { id = "boss.mega_satan", destinationRooms = {}, frontier = true })
  value.visibleChoices = {}
  local second = Planner.plan(value, { id = "boss.mega_satan", destinationRooms = {}, frontier = true }, first)
  assertTrue(not second.decision or not second.decision.primary, "removed entities must remove their marker decision")
end
```

Add it to `tests`.

- [ ] **Step 8: Run tests and verify GREEN**

Run:

```powershell
npm.cmd test
```

Expected: all suites pass, save schema is 4, held detail follows button state, and removed choices do not survive.

- [ ] **Step 9: Commit**

```powershell
git add runcompass/save.lua runcompass/mcm.lua runcompass/ui.lua main.lua tests/run.lua tests/navigation_ui.lua tests/guidance.lua
git commit -m "feat: persist guidance UI preferences"
```

## Task 8: Verify EID and Fair-Play Boundaries

This task explicitly covers Curse of the Blind identity removal as well as EID's descriptive-only role.

**Files:**

- Modify: `runcompass/recommendation.lua`
- Modify: `runcompass/eid.lua`
- Modify: `runcompass/choice_engine.lua`
- Modify: `tests/guidance.lua`

- [ ] **Step 1: Write failing EID non-authority and Blind tests**

Append to `tests/guidance.lua`:

```lua
local ChoiceEngine = require("runcompass.choice_engine")
local EID = require("runcompass.eid")

local function testEidDescriptionCannotChangeChoiceScore()
  local value = snapshot()
  local choices = {
    { id = "choice.1", roomId = 1, kind = "collectible", observedIdentity = { id = 100, name = "Relic" }, eligibleActors = { "primary" }, confidence = "high" }
  }
  local models = {
    featureSummary = function() return { effects = {}, tags = {} } end,
    evaluate = function() return { effects = { offense = 2 }, reasonCodes = {}, warnings = {}, ruleIds = {}, confidence = "high" } end
  }
  local neutral = ChoiceEngine.evaluate(value, choices, {}, models, { describe = function() return "Neutral text" end })
  local hostile = ChoiceEngine.evaluate(value, choices, {}, models, { describe = function() return "DO NOT TAKE; tier zero" end })
  assertEqual(neutral.primary.value, hostile.primary.value, "EID text must not change value")
  assertEqual(neutral.primary.action, hostile.primary.action, "EID text must not change action")
end

local function testBlindChoiceCannotReceiveItemAdviceOrEidText()
  local value = snapshot()
  value.visibility.curseBlind = true
  value.visibleChoices = {
    { id = "blind.1", roomId = 1, kind = "collectible", position = { x = 100, y = 100 }, observedIdentity = nil, eligibleActors = { "primary" } }
  }
  local result = Planner.plan(value, { id = "boss.mega_satan", destinationRooms = {}, frontier = true })
  assertEqual(result.decision.primary.action, "insufficient_information", "Blind item must not receive TAKE/SKIP advice")
  assertEqual(result.decision.primary.description, nil, "Blind item must not receive EID text")
end

local function testEidRejectsMissingOrBlindIdentity()
  local adapter = EID.detect({ getDescription = function() return "hidden description" end })
  assertEqual(adapter:describe(nil, { curseBlind = false }), nil, "missing identity must not query EID")
  assertEqual(adapter:describe(100, { curseBlind = true }), nil, "Blind identity must not query EID")
end
```

Add all three functions to `tests`.

- [ ] **Step 2: Run the guidance suite and verify RED if any boundary is violated**

Run:

```powershell
npx fengari tests/guidance.lua
```

Expected: FAIL because `EID:describe` currently accepts missing/Blind identities. The non-authority score test may already pass and remains as a characterization invariant.

- [ ] **Step 3: Harden EID adapter inputs**

Update `runcompass/eid.lua`:

```lua
function EID:describe(id, visibility)
  if visibility and visibility.curseBlind then return nil end
  if id == nil or not self.available then return nil end
  local ok, value = pcall(self.provider.getDescription, self.provider, id)
  return ok and type(value) == "string" and value or nil
end
```

Update `ChoiceEngine.evaluate` to call:

```lua
description = descriptions and item.id and descriptions:describe(item.id, snapshot.visibility) or nil
```

- [ ] **Step 4: Assert sanitized choices before finalization**

In `runcompass/recommendation.lua`, before adding a choice:

```lua
local blindIdentity = snapshot.visibility and snapshot.visibility.curseBlind
  and (choice.kind == "collectible" or choice.kind == "trinket" or choice.kind == "card")
if blindIdentity then
  choice = {
    id = choice.id,
    roomId = choice.roomId,
    position = choice.position,
    kind = choice.kind,
    choiceGroupId = choice.choiceGroupId,
    eligibleActors = choice.eligibleActors,
    observedIdentity = nil,
    confidence = "none"
  }
end
visibleChoices[#visibleChoices + 1] = choice
```

Do not mutate the snapshot's original choice table.

- [ ] **Step 5: Run the full suite and fair-play diagnostics**

Run:

```powershell
npm.cmd test
```

Expected: all suites pass; EID text changes neither action nor score, and Blind results are `insufficient_information`.

- [ ] **Step 6: Commit**

```powershell
git add runcompass/recommendation.lua runcompass/eid.lua runcompass/choice_engine.lua tests/guidance.lua
git commit -m "test: enforce fair-play guidance boundaries"
```

## Task 9: Documentation, Packaging, Deployment, and In-Game Acceptance

**Files:**

- Modify: `metadata.xml`
- Modify: `README.md`
- Modify: `docs/CONTROLS.md`
- Modify: `docs/RELEASES.md`
- Modify: `scripts/package.ps1` only if the asset smoke test exposes an omission

- [ ] **Step 1: Update version and release documentation**

Set `metadata.xml`:

```xml
<version>1.2.0</version>
```

Add to `docs/RELEASES.md`:

```markdown
## 1.2.0 — Actionable Guidance UI

- Replaces the flat goal list with a three-pane, controller-friendly browser.
- Shows readable goal names, prerequisites, support tier, and current-run eligibility.
- Ranks legitimately revealed route frontiers instead of choosing the first door.
- Evaluates visible items during exploratory routing.
- Adds compact persistent route cards, exact door arrows, and TAKE/BUY/REROLL/SKIP markers.
- Keeps EID descriptive-only and preserves the fair-play visibility boundary.
```

Update `docs/CONTROLS.md` with the exact LB/RB, D-pad, A/B, X/Y, keyboard search, and held-detail bindings. Update `README.md` screenshots/features text to match the three-pane and compact-HUD behavior.

- [ ] **Step 2: Run final automated verification**

Run:

```powershell
npm.cmd test
git diff --check
```

Expected:

- All planner, performance, build-guide, navigation UI, and guidance tests pass.
- Typical planner timing remains below 5 ms.
- Synthetic worst-case timing remains below 12 ms.
- `git diff --check` exits 0.

- [ ] **Step 3: Build a clean package outside the source tree**

Run:

```powershell
$packagePath = 'C:\tmp\run-compass-1.2.0'
powershell -ExecutionPolicy Bypass -File .\scripts\package.ps1 -OutputPath $packagePath
```

Expected: `Packaged Run Compass runtime at C:\tmp\run-compass-1.2.0`.

Verify required files:

```powershell
$required = @(
  'main.lua',
  'metadata.xml',
  'runcompass\browser_model.lua',
  'runcompass\frontier.lua',
  'runcompass\recommendation.lua',
  'runcompass\hud.lua',
  'gfx\ui\compass-arrow.anm2',
  'gfx\ui\guidance-markers.anm2',
  'gfx\ui\guidance-markers.png'
)
foreach ($relative in $required) {
  if (-not (Test-Path -LiteralPath (Join-Path $packagePath $relative))) { throw "Missing package file: $relative" }
}
```

Expected: exits 0 without a missing-file error.

- [ ] **Step 4: Deploy to the active Isaac installation**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 -GamePath "C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth"
```

Expected: deployment path ends in `mods\run-compass`.

Compare tested and deployed runtime hashes:

```powershell
$deployRoot = 'C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\mods\run-compass'
foreach ($relative in @('main.lua', 'runcompass\planner.lua', 'runcompass\ui.lua', 'runcompass\browser_model.lua', 'runcompass\frontier.lua', 'runcompass\recommendation.lua', 'runcompass\hud.lua')) {
  $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path (Get-Location) $relative)).Hash
  $deployedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $deployRoot $relative)).Hash
  if ($sourceHash -ne $deployedHash) { throw "Deployment mismatch: $relative" }
}
```

Expected: exits 0.

- [ ] **Step 5: Execute the in-game acceptance script after a full Isaac restart**

Use a solo Normal Isaac run with EID, MCM, and Repentogon enabled:

1. Open Run Compass with the configured keyboard key; verify three panes and a scrollable list longer than ten entries.
2. Repeat using only Xbox controls: LB/RB, D-pad, X/Y, A, and B.
3. Select Mega Satan and verify the HUD label is `Mega Satan`.
4. Clear the starting room and verify one exact door receives an arrow.
5. Enter a treasure room and verify the visible pedestal receives TAKE, REROLL, or SKIP advice.
6. Verify the explanation names a character/build reason and confidence.
7. Verify EID remains readable and its prose does not appear as a Run Compass score.
8. Pick up or reroll the item and verify the marker/card update immediately.
9. Leave and re-enter rooms, change floors, and continue a saved run; verify no stale marker remains.
10. Inspect `Documents\My Games\Binding of Isaac Repentance+\log.txt` and the Repentogon console for recurring Run Compass errors.

Expected: all ten checks pass with no game-state mutation.

- [ ] **Step 6: Commit release changes**

```powershell
git add metadata.xml README.md docs/CONTROLS.md docs/RELEASES.md
git commit -m "docs: release Run Compass 1.2.0 guidance UI"
```

- [ ] **Step 7: Push the verified source state**

```powershell
git status --short
git push origin main
```

Expected:

- `git status --short` prints nothing.
- GitHub `main` advances to the final verified commit.

## Final Completion Gate

Do not call the feature complete until all of the following are true:

- The three-pane browser is dynamic, scrollable, and controller-complete.
- Internal goal IDs never appear as the primary target label.
- `explore` selects a ranked revealed frontier and exposes `nextDoorSlot`.
- `explore` attaches current-room visible-choice evaluation.
- Treasure-room pedestals receive character/build-aware action guidance.
- Door and entity markers use live positions and valid assets.
- Compact guidance remains visible until room/action invalidation.
- EID remains optional and descriptive-only.
- Fair-play and performance suites pass.
- Clean packaging, deployment hash checks, full restart, and the ten-step in-game script pass.

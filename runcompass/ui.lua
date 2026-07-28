local Presentation = require("runcompass.presentation")
local Strings = require("runcompass.strings")
local BrowserModel = require("runcompass.browser_model")
local Hud = require("runcompass.hud")

local UI = {}
UI.__index = UI

local function loadSprite(factory, path, animation)
  if type(factory) ~= "function" then return nil end
  local ok, sprite = pcall(factory)
  if not ok or not sprite then return nil end
  local loaded = pcall(sprite.Load, sprite, path, true)
  if not loaded then return nil end
  pcall(sprite.Play, sprite, animation, true)
  return sprite
end

local function renderText(isaac, text, x, y, scale, color)
  color = color or { 1, 1, 1, 1 }
  if type(isaac.RenderScaledText) == "function" then
    isaac.RenderScaledText(text or "", x, y, scale or 1, scale or 1, color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
  elseif type(isaac.RenderText) == "function" then
    isaac.RenderText(text or "", x, y, color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
  end
end

local function toScreen(isaac, x, y)
  if type(isaac.WorldToScreen) == "function" and type(Vector) == "function" then
    local ok, screen = pcall(isaac.WorldToScreen, Vector(x, y))
    if ok and screen then return screen.X or x, screen.Y or y end
  end
  return x, y
end

local function cycle(values, value)
  local current = 1
  for index, candidate in ipairs(values) do
    if candidate == value then current = index end
  end
  return values[current % #values + 1]
end

function UI.new(env)
  local saved = (env.state and env.state.browser) or {}
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

function UI:browserModel()
  local snapshotSource = self.env.getSnapshot or self.env.snapshot
  local snapshot = type(snapshotSource) == "table" and snapshotSource or {}
  if type(snapshotSource) == "function" then
    local ok, result = pcall(snapshotSource)
    if ok and type(result) == "table" then snapshot = result end
  end
  local state = {}
  for key, value in pairs(self.browserState) do state[key] = value end
  state.filters = {}
  for key, value in pairs(self.browserState.filters) do state.filters[key] = value end
  state.filters.query = self.query
  return BrowserModel.build(self.env.entries, snapshot, state, 10)
end

function UI:resetBrowserPosition()
  self.browserState.selectedIndex = 1
  self.browserState.scrollOffset = 1
  self.browserState.detailOffset = 1
end

function UI:changeCategory(delta)
  local model = self:browserModel()
  local current = 1
  for index, category in ipairs(model.categories) do
    if category.id == self.browserState.category then current = index end
  end
  local count = #model.categories
  if count == 0 then return end
  local nextIndex = ((current - 1 + delta) % count) + 1
  self.browserState.category = model.categories[nextIndex].id
  self:resetBrowserPosition()
  if self.env.state and self.env.state.browser then self.env.state.browser.category = self.browserState.category end
end

function UI:toggleBrowser()
  self.open = not self.open
  if self.open then
    self.query = ""
    self:resetBrowserPosition()
  end
end

function UI:togglePinned()
  self.env.state.pinned = not self.env.state.pinned
end

function UI:selectGoal(model)
  local selected = model and model.goals[model.selectedIndex]
  if not selected then return end
  if selected and self.env.onGoalSelected then self.env.onGoalSelected(selected) end
  self.open = false
end

function UI:input()
  local input, keyboard, controller, buttonAction = self.env.input, self.env.keyboard, self.env.controller, self.env.buttonAction
  if not input then return end
  local state = self.env.state
  local held = function(code)
    return code ~= nil and input.IsButtonPressed and input.IsButtonPressed(code, 0)
  end
  self.detailHeld = held(state.bindings.keyboardDetail) or held(state.bindings.controllerDetail)
  local pressed = function(code) return code ~= nil and input.IsButtonTriggered and input.IsButtonTriggered(code, 0) end
  local actionPressed = function(name)
    local action = buttonAction and buttonAction[name]
    return action ~= nil and input.IsActionTriggered and input.IsActionTriggered(action, 0)
  end

  if pressed(state.bindings.keyboardGoal) then self:toggleBrowser(); return end
  if pressed(state.bindings.keyboardToggle) then self:togglePinned(); return end
  if not self.open then
    if pressed(state.bindings.controllerGoal) then self:toggleBrowser(); return end
    if pressed(state.bindings.controllerToggle) then self:togglePinned(); return end
    return
  end

  local function moveGoal(delta)
    local model = self:browserModel()
    if model.resultCount == 0 then
      self.browserState.selectedIndex = 0
      self.browserState.scrollOffset = 1
    else
      self.browserState.selectedIndex = math.max(1, math.min(model.resultCount, model.selectedIndex + delta))
      local refreshed = self:browserModel()
      self.browserState.selectedIndex = refreshed.selectedIndex
      self.browserState.scrollOffset = refreshed.scrollOffset
    end
    self.browserState.detailOffset = 1
  end

  local function moveVertical(delta)
    if self.browserState.focusedPane == "categories" then
      self:changeCategory(delta)
    elseif self.browserState.focusedPane == "details" then
      local lineCount = #(self:browserModel().details.lines or {})
      self.browserState.detailOffset = math.max(1, math.min(math.max(1, lineCount - 4), self.browserState.detailOffset + delta))
    else
      moveGoal(delta)
    end
  end

  local function movePane(delta)
    local panes = { "categories", "goals", "details" }
    local current = 2
    for index, pane in ipairs(panes) do
      if pane == self.browserState.focusedPane then current = index end
    end
    self.browserState.focusedPane = panes[math.max(1, math.min(#panes, current + delta))]
  end

  local function changeFilter(key, values)
    self.browserState.filters[key] = cycle(values, self.browserState.filters[key])
    self:resetBrowserPosition()
  end

  if actionPressed("ACTION_MENULB") or actionPressed("ACTION_MENULT") then self:changeCategory(-1); return end
  if actionPressed("ACTION_MENURB") or actionPressed("ACTION_MENURT") then self:changeCategory(1); return end
  if actionPressed("ACTION_MENUUP") then moveVertical(-1); return end
  if actionPressed("ACTION_MENUDOWN") then moveVertical(1); return end
  if actionPressed("ACTION_MENULEFT") then movePane(-1); return end
  if actionPressed("ACTION_MENURIGHT") then movePane(1); return end
  if actionPressed("ACTION_MENUTAB") then changeFilter("kind", { "all", "boss", "collectible" }); return end
  if actionPressed("ACTION_MENUEX") then changeFilter("status", { "all", "locked", "already_unlocked", "instructional_only", "catalog_update_required" }); return end
  local model = self:browserModel()
  if actionPressed("ACTION_MENUCONFIRM") then self:selectGoal(model); return end
  if actionPressed("ACTION_MENUBACK") then self.open = false; return end

  if pressed(state.bindings.controllerGoal) then self:toggleBrowser(); return end
  if pressed(state.bindings.controllerToggle) then self:togglePinned(); return end

  if controller and pressed(controller.LEFT_SHOULDER) then self:changeCategory(-1); return end
  if controller and pressed(controller.RIGHT_SHOULDER) then self:changeCategory(1); return end
  if keyboard and pressed(keyboard.KEY_UP) then moveVertical(-1); return end
  if keyboard and pressed(keyboard.KEY_DOWN) then moveVertical(1); return end
  if controller and pressed(controller.DPAD_UP) then moveVertical(-1); return end
  if controller and pressed(controller.DPAD_DOWN) then moveVertical(1); return end
  if keyboard and pressed(keyboard.KEY_LEFT) then movePane(-1); return end
  if keyboard and pressed(keyboard.KEY_RIGHT) then movePane(1); return end
  if controller and pressed(controller.DPAD_LEFT) then movePane(-1); return end
  if controller and pressed(controller.DPAD_RIGHT) then movePane(1); return end
  if keyboard and pressed(keyboard.KEY_TAB) then changeFilter("kind", { "all", "boss", "collectible" }); return end
  if keyboard and pressed(keyboard.KEY_S) then changeFilter("status", { "all", "locked", "already_unlocked", "instructional_only", "catalog_update_required" }); return end
  if keyboard and pressed(keyboard.KEY_L) then
    local letter = self.browserState.filters.letter
    self.browserState.filters.letter = letter == "all" and "A" or (letter == "Z" and "all" or string.char(string.byte(letter) + 1))
    self:resetBrowserPosition()
    return
  end
  if controller and pressed(controller.BUTTON_X) then changeFilter("kind", { "all", "boss", "collectible" }); return end
  if controller and pressed(controller.BUTTON_Y) then changeFilter("status", { "all", "locked", "already_unlocked", "instructional_only", "catalog_update_required" }); return end

  if keyboard and pressed(keyboard.KEY_ENTER) then self:selectGoal(model); return end
  if controller and pressed(controller.BUTTON_A) then self:selectGoal(model); return end
  if keyboard and pressed(keyboard.KEY_ESCAPE) then self.open = false; return end
  if controller and pressed(controller.BUTTON_B) then self.open = false; return end
  if keyboard and pressed(keyboard.KEY_BACKSPACE) then self.query = string.sub(self.query, 1, -2); self:resetBrowserPosition(); return end
  if keyboard and keyboard.KEY_A ~= nil and keyboard.KEY_Z ~= nil then
    for code = keyboard.KEY_A, keyboard.KEY_Z do
      if pressed(code) then
        self.query = self.query .. string.char(string.byte("A") + code - keyboard.KEY_A)
        self:resetBrowserPosition()
        return
      end
    end
  end
  if keyboard then
    local punctuation = {
      { "KEY_SPACE", " " }, { "KEY_MINUS", "-" }, { "KEY_APOSTROPHE", "'" },
      { "KEY_COMMA", "," }, { "KEY_PERIOD", "." }, { "KEY_SLASH", "/" }
    }
    for _, entry in ipairs(punctuation) do
      if pressed(keyboard[entry[1]]) then self.query = self.query .. entry[2]; self:resetBrowserPosition(); return end
    end
  end
end

function UI:renderBrowser()
  local isaac = self.env.isaac
  local model = self:browserModel()
  local state = self.browserState
  local top, categoryX, goalsX, detailsX = 34, 32, 190, 430
  local gold, focused, active, muted = { 1, 0.78, 0.25, 1 }, { 1, 1, 0.75, 1 }, { 0.7, 1, 0.7, 1 }, { 0.75, 0.75, 0.75, 1 }

  renderText(isaac, Strings.get("browser.title"), 20, 18, 1, gold)
  for index, category in ipairs(model.categories) do
    local isActive = category.id == model.activeCategory
    local prefix = isActive and "> " or "  "
    local color = isActive and active or muted
    if state.focusedPane == "categories" and isActive then color = focused end
    renderText(isaac, prefix .. category.label .. " (" .. category.count .. ")", categoryX, top + (index - 1) * 13, 0.8, color)
  end

  if #model.rows == 0 then
    renderText(isaac, Strings.get("browser.empty"), goalsX, top, 0.8, muted)
  else
    for index, row in ipairs(model.rows) do
      local prefix = row.selected and "> " or "  "
      local color = row.selected and (state.focusedPane == "goals" and focused or active) or muted
      renderText(isaac, prefix .. row.name .. " - " .. row.statusLabel, goalsX, top + (index - 1) * 13, 0.8, color)
    end
  end

  local details = model.details or {}
  renderText(isaac, details.name or Strings.get("browser.empty"), detailsX, top, 0.9, state.focusedPane == "details" and focused or gold)
  if details.statusLabel then renderText(isaac, details.statusLabel, detailsX, top + 13, 0.75, active) end
  local lines = details.lines or {}
  local detailOffset = math.max(1, state.detailOffset or 1)
  for index = detailOffset, math.min(#lines, detailOffset + 4) do
    renderText(isaac, lines[index], detailsX, top + 26 + (index - detailOffset) * 12, 0.72, muted)
  end

  renderText(isaac, Strings.get("browser.search", self.query), 32, 198, 0.8, { 1, 1, 1, 1 })
  renderText(isaac, Strings.get("browser.categoryControls"), 32, 211, 0.72, muted)
  renderText(isaac, Strings.get("browser.filterControls"), 190, 211, 0.72, muted)
  renderText(isaac, Strings.get("browser.selectControls"), 390, 211, 0.72, muted)
  if self.env.mcmAvailable == false then renderText(isaac, Strings.get("browser.mcmNotice"), 32, 224, 0.72, gold) end
end

function UI:render(snapshot, recommendation)
  local isaac = self.env.isaac
  if not isaac or (type(isaac.RenderText) ~= "function" and type(isaac.RenderScaledText) ~= "function") then return end
  if self.open then
    self:renderBrowser()
    return
  end
  if self.env.mcmAvailable == false and not self.mcmNoticeShown then
    renderText(isaac, Strings.get("hud.installMcm"), 20, 18, 1, { 1, 0.7, 0.3, 1 })
    self.mcmNoticeShown = true
  end
  if not recommendation or not self.env.state.hud.visible then return end
  if not self.env.state.pinned and snapshot.currentRoomClear == false then return end

  local selectedGoal = type(self.env.getSelectedGoal) == "function" and self.env.getSelectedGoal() or nil
  local targetName = selectedGoal and selectedGoal.name or Strings.get("hud.unknownGoal")
  local expanded = self.detailHeld == true
  local view = Hud.view(recommendation, targetName, expanded, self.env.state.decision)
  local scale = self.env.state.hud.scale or 1
  local cardX = 20 + (self.env.state.hud.x or 0)
  local cardY = 18 + (self.env.state.hud.y or 0)

  renderText(isaac, Strings.get("hud.target", view.target), cardX, cardY, 0.8 * scale, { 0.8, 0.8, 0.9, 1 })
  for index, line in ipairs(view.lines) do
    renderText(isaac, Presentation.label(line), cardX, cardY + index * 12, 0.7 * scale, { 1, 0.92, 0.75, 1 })
  end
  if view.action then
    renderText(isaac, view.action, cardX, cardY + (#view.lines + 1) * 12, 0.75 * scale, { 0.55, 0.9, 0.62, 1 })
  end

  local doorPosition = Hud.doorPosition(self.env.game, view.nextDoorSlot)
  if doorPosition then
    local screenX, screenY = toScreen(isaac, doorPosition.x, doorPosition.y)
    local rotations = { [0] = 180, [1] = -90, [2] = 0, [3] = 90, [4] = 180, [5] = -90, [6] = 0, [7] = 90 }
    if self.arrowSprite then
      self.arrowSprite.Rotation = rotations[view.nextDoorSlot] or 0
      self.arrowSprite.Scale = Vector(0.5 * scale, 0.5 * scale)
      self.arrowSprite:Render(Vector(screenX, screenY))
    else
      renderText(isaac, "→", screenX - 8, screenY - 8, 0.5 * scale, { 1, 0.84, 0.2, 1 })
    end
  end

  if view.choicePosition then
    local screenX, screenY = toScreen(isaac, view.choicePosition.x, view.choicePosition.y)
    local animation = view.action == "SKIP" and "Skip"
      or view.action == "REROLL" and "Reroll"
      or (view.warnings and #view.warnings > 0) and "Caution"
      or "Take"
    if self.markerSprite then
      self.markerSprite:Play(animation, true)
      self.markerSprite.Scale = Vector(0.65 * scale, 0.65 * scale)
      self.markerSprite:Render(Vector(screenX, screenY - 24))
    else
      renderText(isaac, view.action or "◆", screenX - 12, screenY - 24, 0.45 * scale, { 0.55, 0.9, 0.62, 1 })
    end
  end
end

return UI

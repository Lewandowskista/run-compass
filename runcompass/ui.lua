local Browser = require("runcompass.browser")
local Presentation = require("runcompass.presentation")

local UI = {}
UI.__index = UI

function UI.new(env)
  return setmetatable({ env = env, open = false, query = "", index = 1, filters = { kind = "all", status = "all", letter = "all" } }, UI)
end

function UI:toggleBrowser()
  self.open = not self.open
  if self.open then self.query = ""; self.index = 1 end
end

function UI:togglePinned()
  self.env.state.pinned = not self.env.state.pinned
end

function UI:selectGoal(entries)
  local selected = entries[self.index]
  if selected and self.env.onGoalSelected then self.env.onGoalSelected(selected) end
  self.open = false
end

function UI:input()
  local input, keyboard, controller = self.env.input, self.env.keyboard, self.env.controller
  if not input then return end
  local state = self.env.state
  if input.IsButtonTriggered and input.IsButtonTriggered(state.bindings.keyboardGoal, 0) then self:toggleBrowser() end
  if input.IsButtonTriggered and input.IsButtonTriggered(state.bindings.keyboardToggle, 0) then self:togglePinned() end
  if input.IsButtonTriggered and input.IsButtonTriggered(state.bindings.controllerGoal, 0) then self:toggleBrowser() end
  if input.IsButtonTriggered and input.IsButtonTriggered(state.bindings.controllerToggle, 0) then self:togglePinned() end
  if not self.open or not keyboard or not input.IsButtonTriggered then return end
  local entries = Browser.filter(self.env.entries, { query = self.query, kind = self.filters.kind, status = self.filters.status })
  if keyboard.KEY_UP and input.IsButtonTriggered(keyboard.KEY_UP, 0) then self.index = math.max(1, self.index - 1); return end
  if keyboard.KEY_DOWN and input.IsButtonTriggered(keyboard.KEY_DOWN, 0) then self.index = math.min(math.max(1, #entries), self.index + 1); return end
  if keyboard.KEY_TAB and input.IsButtonTriggered(keyboard.KEY_TAB, 0) then
    local kinds = { "all", "boss", "collectible" }
    local current = 1
    for index, kind in ipairs(kinds) do if kind == self.filters.kind then current = index end end
    self.filters.kind = kinds[current % #kinds + 1]
    self.index = 1
    return
  end
  if controller and controller.DPAD_UP and input.IsButtonTriggered(controller.DPAD_UP, 0) then self.index = math.max(1, self.index - 1); return end
  if controller and controller.DPAD_DOWN and input.IsButtonTriggered(controller.DPAD_DOWN, 0) then self.index = math.min(math.max(1, #entries), self.index + 1); return end
  if controller and controller.BUTTON_X and input.IsButtonTriggered(controller.BUTTON_X, 0) then
    local kinds = { "all", "boss", "collectible" }
    local current = 1
    for index, kind in ipairs(kinds) do if kind == self.filters.kind then current = index end end
    self.filters.kind = kinds[current % #kinds + 1]
    self.index = 1
    return
  end
  if input.IsButtonTriggered(keyboard.KEY_ESCAPE, 0) then self.open = false; return end
  if input.IsButtonTriggered(keyboard.KEY_BACKSPACE, 0) then self.query = string.sub(self.query, 1, -2); return end
  if input.IsButtonTriggered(keyboard.KEY_ENTER, 0) then self:selectGoal(Browser.filter(self.env.entries, { query = self.query, kind = self.filters.kind, status = self.filters.status })); return end
  for code = keyboard.KEY_A, keyboard.KEY_Z do
    if input.IsButtonTriggered(code, 0) then self.query = self.query .. string.char(code); break end
  end
end

function UI:render(snapshot, recommendation)
  local isaac = self.env.isaac
  if not isaac or type(isaac.RenderText) ~= "function" then return end
  if self.env.mcmAvailable == false then
    isaac.RenderText("Run Compass: install Mod Config Menu for settings", 20, 18, 1, 0.7, 0.3, 1)
  end
  if self.open then
    local entries = Browser.filter(self.env.entries, { query = self.query, kind = self.filters.kind, status = self.filters.status })
    isaac.RenderText("Run Compass - search: " .. self.query .. " / " .. self.filters.kind, 20, 30, 1, 1, 1, 1)
    for index = 1, math.min(#entries, 10) do
      local prefix = index == self.index and "> " or "  "
      isaac.RenderText(prefix .. entries[index].name, 24, 45 + index * 12, 1, 1, 1, 1)
    end
    return
  end
  if not recommendation or not self.env.state.hud.visible then return end
  if not self.env.state.pinned and snapshot.currentRoomClear == false then return end
  local lines = Presentation.lines(recommendation)
  for index, line in ipairs(lines) do
    isaac.RenderText(line, 20, 30 + index * 12, 1, 0.9, 0.65, 1)
  end
  if recommendation.nextDoorSlot ~= nil then
    local x, y = 20, 30 + (#lines + 1) * 12
    local game = self.env.game
    if game and game.GetLevel then
      local ok, room = pcall(function() return game:GetLevel():GetCurrentRoom() end)
      if ok and room and room.GetDoorSlotPosition then
        local position = room:GetDoorSlotPosition(recommendation.nextDoorSlot)
        if position then x, y = position.X - 8, position.Y - 8 end
      end
    end
    isaac.RenderText("→", x, y, 0.4, 1, 0.4, 1)
  end
end

return UI

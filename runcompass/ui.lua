local Browser = require("runcompass.browser")
local Presentation = require("runcompass.presentation")
local Strings = require("runcompass.strings")

local UI = {}
UI.__index = UI

function UI.new(env)
  return setmetatable({ env = env, open = false, query = "", index = 1, mcmNoticeShown = false, filters = { kind = "all", status = "all", letter = "all", character = "all", unlockMethod = "all", completionMark = "all" } }, UI)
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
  local pressed = function(code) return code ~= nil and input.IsButtonTriggered and input.IsButtonTriggered(code, 0) end
  if pressed(state.bindings.keyboardGoal) then self:toggleBrowser() end
  if pressed(state.bindings.keyboardToggle) then self:togglePinned() end
  if pressed(state.bindings.controllerGoal) then self:toggleBrowser() end
  if pressed(state.bindings.controllerToggle) then self:togglePinned() end
  if not self.open or not keyboard or not input.IsButtonTriggered then return end
  self.filters.query = self.query
  local entries = Browser.filter(self.env.entries, self.filters)
  if pressed(keyboard.KEY_UP) then self.index = math.max(1, self.index - 1); return end
  if pressed(keyboard.KEY_DOWN) then self.index = math.min(math.max(1, #entries), self.index + 1); return end
  if pressed(keyboard.KEY_TAB) then
    local kinds = { "all", "boss", "collectible" }
    local current = 1
    for index, kind in ipairs(kinds) do if kind == self.filters.kind then current = index end end
    self.filters.kind = kinds[current % #kinds + 1]
    self.index = 1
    return
  end
  if pressed(keyboard.KEY_S) then
    local statuses = { "all", "locked", "already_unlocked", "instructional_only", "catalog_update_required" }
    local current = 1; for index, status in ipairs(statuses) do if status == self.filters.status then current = index end end
    self.filters.status = statuses[current % #statuses + 1]; self.index = 1; return
  end
  if pressed(keyboard.KEY_L) then
    local current = self.filters.letter
    self.filters.letter = current == "all" and "A" or (current == "Z" and "all" or string.char(string.byte(current) + 1))
    self.index = 1; return
  end
  if controller and pressed(controller.DPAD_UP) then self.index = math.max(1, self.index - 1); return end
  if controller and pressed(controller.DPAD_DOWN) then self.index = math.min(math.max(1, #entries), self.index + 1); return end
  if controller and pressed(controller.BUTTON_X) then
    local kinds = { "all", "boss", "collectible" }
    local current = 1
    for index, kind in ipairs(kinds) do if kind == self.filters.kind then current = index end end
    self.filters.kind = kinds[current % #kinds + 1]
    self.index = 1
    return
  end
  if controller and pressed(controller.BUTTON_Y) then
    local statuses = { "all", "locked", "already_unlocked", "instructional_only", "catalog_update_required" }
    local current = 1; for index, status in ipairs(statuses) do if status == self.filters.status then current = index end end
    self.filters.status = statuses[current % #statuses + 1]; self.index = 1; return
  end
  if pressed(keyboard.KEY_ESCAPE) then self.open = false; return end
  if pressed(keyboard.KEY_BACKSPACE) then self.query = string.sub(self.query, 1, -2); return end
  if pressed(keyboard.KEY_ENTER) then self:selectGoal(Browser.filter(self.env.entries, self.filters)); return end
  for code = keyboard.KEY_A, keyboard.KEY_Z do
    if pressed(code) then self.query = self.query .. string.char(code); break end
  end
  if pressed(keyboard.KEY_SPACE) then self.query = self.query .. " " end
  if pressed(keyboard.KEY_MINUS) then self.query = self.query .. "-" end
end

function UI:render(snapshot, recommendation)
  local isaac = self.env.isaac
  if not isaac or type(isaac.RenderText) ~= "function" then return end
  if self.env.mcmAvailable == false and not self.mcmNoticeShown then
    isaac.RenderText(Strings.get("hud.installMcm"), 20, 18, 1, 0.7, 0.3, 1)
    self.mcmNoticeShown = true
  end
  if self.open then
    self.filters.query = self.query
    local entries = Browser.filter(self.env.entries, self.filters)
    isaac.RenderText(Strings.get("browser.title") .. " - search: " .. self.query .. " / " .. Strings.get("browser.filters", self.filters.kind, self.filters.status, self.filters.letter), 20, 30, 1, 1, 1, 1)
    for index = 1, math.min(#entries, 10) do
      local prefix = index == self.index and "> " or "  "
      isaac.RenderText(prefix .. entries[index].name, 24, 45 + index * 12, 1, 1, 1, 1)
    end
    if self.env.mcmAvailable == false then isaac.RenderText(Strings.get("browser.mcmNotice"), 24, 180, 0.8, 0.7, 0.5, 1) end
    return
  end
  if not recommendation or not self.env.state.hud.visible then return end
  if not self.env.state.pinned and snapshot.currentRoomClear == false then return end
  local lines = Presentation.lines(recommendation, self.env.state.decision)
  local selected = self.env.state.selectedGoalId and self.env.state.selectedGoalId or "Delirium"
  isaac.RenderText(Strings.get("hud.target", selected), 20 + (self.env.state.hud.x or 0), 18 + (self.env.state.hud.y or 0), 0.8 * (self.env.state.hud.scale or 1), 0.8, 0.9, 1)
  for index, line in ipairs(lines) do
    isaac.RenderText(line, 20, 30 + index * 12, 1, 0.9, 0.65, 1)
  end
  if recommendation.nextDoorSlot ~= nil then
    local x, y = 20 + (self.env.state.hud.x or 0), 30 + (#lines + 1) * 12 + (self.env.state.hud.y or 0)
    local game = self.env.game
    if game and game.GetLevel then
      local ok, room = pcall(function() return game:GetLevel():GetCurrentRoom() end)
      if ok and room and room.GetDoorSlotPosition then
        local position = room:GetDoorSlotPosition(recommendation.nextDoorSlot)
        if position then x, y = position.X - 8, position.Y - 8 end
      end
    end
    isaac.RenderText("→", x, y, 0.4 * (self.env.state.hud.scale or 1), 1, 0.4, 1)
  end
  if recommendation.decision and recommendation.decision.primary and recommendation.decision.primary.position and (not self.env.state.decision or self.env.state.decision.autoCompare ~= false) then
    local position = recommendation.decision.primary.position
    isaac.RenderText("◆", position.x or 0, position.y or 0, 0.5 * (self.env.state.hud.scale or 1), 0.9, 0.8, 0.2)
  end
end

return UI

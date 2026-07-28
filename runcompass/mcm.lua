local MCM = {}

function MCM.register(state, onChanged)
  local menu = rawget(_G, "ModConfigMenu") or rawget(_G, "MCM")
  if type(menu) ~= "table" or type(menu.AddSetting) ~= "function" then return false end
  local optionType = menu.OptionType or {}
  local function bindingName(value, isController)
    local names = isController and menu.ControllerToString or menu.KeyboardToString
    if type(names) == "table" and names[value] then return names[value] end
    if value == nil or value == -1 then return "Unbound" end
    return tostring(value)
  end
  local function setting(category, name, kind, display, current, change, info, minimum, maximum, modifyBy)
    local config = {
      Type = optionType[kind],
      CurrentSetting = current,
      Display = display,
      OnChange = function(value) change(value); if onChanged then onChanged() end end,
      Info = info or {}
    }
    if kind == "NUMBER" then config.Minimum = minimum or 0.5; config.Maximum = maximum or 2; config.ModifyBy = modifyBy or 0.1 end
    if kind == "KEYBIND_KEYBOARD" or kind == "KEYBIND_CONTROLLER" then
      local isController = kind == "KEYBIND_CONTROLLER"
      config.PopupGfx = menu.PopupGfx and menu.PopupGfx.WIDE_SMALL or nil
      config.PopupWidth = 280
      config.Popup = function()
        local device = isController and "controller" or "keyboard"
        return "Press a button on your " .. device .. " to change this binding."
          .. "$newline$newlinePress the current button to keep it unchanged."
          .. "$newlinePress Back to clear it."
      end
    end
    pcall(menu.AddSetting, "Run Compass", category, config)
  end
  setting("General", "Goal browser", "KEYBIND_KEYBOARD", function() return "Goal browser: " .. bindingName(state.bindings.keyboardGoal, false) end, function() return state.bindings.keyboardGoal end, function(value) state.bindings.keyboardGoal = value end)
  setting("General", "Toggle guidance", "KEYBIND_KEYBOARD", function() return "Toggle guidance: " .. bindingName(state.bindings.keyboardToggle, false) end, function() return state.bindings.keyboardToggle end, function(value) state.bindings.keyboardToggle = value end)
  setting("General", "Controller goal browser", "KEYBIND_CONTROLLER", function() return "Controller goal browser: " .. bindingName(state.bindings.controllerGoal, true) end, function() return state.bindings.controllerGoal end, function(value) state.bindings.controllerGoal = value end)
  setting("General", "Controller guidance", "KEYBIND_CONTROLLER", function() return "Controller guidance: " .. bindingName(state.bindings.controllerToggle, true) end, function() return state.bindings.controllerToggle end, function(value) state.bindings.controllerToggle = value end)
  setting("HUD", "Enabled", "BOOLEAN", function() return "HUD: " .. (state.hud.visible and "On" or "Off") end, function() return state.hud.visible end, function(value) state.hud.visible = value end)
  setting("HUD", "Pinned", "BOOLEAN", function() return "Pinned: " .. (state.pinned and "On" or "Off") end, function() return state.pinned end, function(value) state.pinned = value end)
  setting("HUD", "Scale", "NUMBER", function() return "Scale: " .. tostring(state.hud.scale) end, function() return state.hud.scale end, function(value) state.hud.scale = value end)
  setting("HUD", "X position", "NUMBER", function() return "X: " .. tostring(state.hud.x) end, function() return state.hud.x end, function(value) state.hud.x = math.max(-400, math.min(400, tonumber(value) or 0)) end, nil, -400, 400, 10)
  setting("HUD", "Y position", "NUMBER", function() return "Y: " .. tostring(state.hud.y) end, function() return state.hud.y end, function(value) state.hud.y = math.max(-240, math.min(240, tonumber(value) or 0)) end, nil, -240, 240, 10)
  setting("Diagnostics", "Developer diagnostics", "BOOLEAN", function() return "Diagnostics: " .. (state.diagnostics and "On" or "Off") end, function() return state.diagnostics end, function(value) state.diagnostics = value == true end)
  setting("Guide", "Automatic comparisons", "BOOLEAN", function() return "Comparisons: " .. (state.decision.autoCompare and "On" or "Off") end, function() return state.decision.autoCompare end, function(value) state.decision.autoCompare = value == true end)
  setting("Guide", "Detail level", "NUMBER", function() return "Detail: " .. tostring(state.decision.detailLevel) end, function() return state.decision.detailLevel end, function(value) state.decision.detailLevel = math.max(1, math.min(3, math.floor(tonumber(value) or 2))) end, nil, 1, 3, 1)
  setting("Guide", "Show confidence", "BOOLEAN", function() return "Confidence: " .. (state.decision.showConfidence and "On" or "Off") end, function() return state.decision.showConfidence end, function(value) state.decision.showConfidence = value == true end)
  setting("Guide", "Show warnings", "BOOLEAN", function() return "Warnings: " .. (state.decision.showWarnings and "On" or "Off") end, function() return state.decision.showWarnings end, function(value) state.decision.showWarnings = value == true end)
  setting("Guide", "EID descriptions", "BOOLEAN", function() return "EID text: " .. (state.decision.eidDescriptions and "On" or "Off") end, function() return state.decision.eidDescriptions end, function(value) state.decision.eidDescriptions = value == true end)
  if type(menu.AddText) == "function" then
    pcall(menu.AddText, "Run Compass", "Info", function() return "Run Compass [REP+]" end)
    pcall(menu.AddText, "Run Compass", "Info", function() return "MCM config active; Repentogon enables enhanced progress tracking." end)
  end
  return true
end

return MCM

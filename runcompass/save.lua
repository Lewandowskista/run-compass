local Save = {}
local CURRENT_SCHEMA = 4

local function defaults()
  return {
    schemaVersion = CURRENT_SCHEMA,
    selectedGoalId = nil,
    pinned = false,
    hud = { scale = 1, x = 0, y = 0, visible = true },
    diagnostics = false,
    decision = { autoCompare = true, detailLevel = 2, showConfidence = true, showWarnings = true, eidDescriptions = true },
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
      keyboardGoal = 295,
      keyboardToggle = 296,
      keyboardDetail = 297,
      controllerGoal = 10,
      controllerDetail = 11,
      controllerToggle = 13
    }
  }
end

function Save.migrate(data)
  local result = defaults()
  if type(data) ~= "table" then return result end
  for key, value in pairs(data) do if key ~= "schemaVersion" then result[key] = value end end
  result.schemaVersion = CURRENT_SCHEMA
  local defaultHud, defaultBindings = defaults().hud, defaults().bindings
  result.hud = result.hud or {}
  result.hud.scale = math.max(0.5, math.min(2, tonumber(result.hud.scale) or defaultHud.scale))
  result.hud.x = math.max(-400, math.min(400, tonumber(result.hud.x) or defaultHud.x))
  result.hud.y = math.max(-240, math.min(240, tonumber(result.hud.y) or defaultHud.y))
  result.hud.visible = result.hud.visible ~= false
  result.bindings = result.bindings or {}
  for key, value in pairs(defaultBindings) do
    if result.bindings[key] == nil then result.bindings[key] = value end
    result.bindings[key] = tonumber(result.bindings[key]) or value
  end
  -- 117-119 shipped as keyboard defaults but are not GLFW keycodes, so they can
  -- never trigger; remapping them to F6/F7/F8 cannot clobber a real assignment
  local legacyKeyRemap = { [117] = 295, [118] = 296, [119] = 297 }
  for _, key in ipairs({ "keyboardGoal", "keyboardToggle", "keyboardDetail" }) do
    result.bindings[key] = legacyKeyRemap[result.bindings[key]] or result.bindings[key]
  end
  if result.pinned == nil then result.pinned = false end
  result.pinned = result.pinned == true
  result.diagnostics = result.diagnostics == true
  local defaultDecision, defaultBrowser = defaults().decision, defaults().browser
  result.decision = result.decision or {}
  result.decision.autoCompare = result.decision.autoCompare ~= false
  result.decision.detailLevel = math.max(1, math.min(3, math.floor(tonumber(result.decision.detailLevel) or defaultDecision.detailLevel)))
  result.decision.showConfidence = result.decision.showConfidence ~= false
  result.decision.showWarnings = result.decision.showWarnings ~= false
  result.decision.eidDescriptions = result.decision.eidDescriptions ~= false
  result.browser = result.browser or {}
  for key, value in pairs(defaultBrowser) do if result.browser[key] == nil then result.browser[key] = value end end
  return result
end

function Save.encode(data)
  return Save.migrate(data)
end

local function serialize(value)
  if type(value) == "string" then return string.format("%q", value) end
  if type(value) == "number" or type(value) == "boolean" then return tostring(value) end
  if type(value) ~= "table" then return "nil" end
  local parts = {}
  for key, item in pairs(value) do
    local serializedKey = type(key) == "string" and string.format("[%q]", key) or "[" .. tostring(key) .. "]"
    parts[#parts + 1] = serializedKey .. "=" .. serialize(item)
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

function Save.serialize(data)
  return "return " .. serialize(Save.migrate(data))
end

function Save.deserialize(encoded)
  if type(encoded) ~= "string" or encoded == "" then return defaults() end
  local chunk = load(encoded, "runcompass-save", "t", {})
  if not chunk then return defaults() end
  local ok, value = pcall(chunk)
  if not ok then return defaults() end
  return Save.migrate(value)
end

return Save

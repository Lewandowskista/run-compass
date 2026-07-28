local Save = {}
local CURRENT_SCHEMA = 2

local function defaults()
  return {
    schemaVersion = CURRENT_SCHEMA,
    selectedGoalId = nil,
    pinned = false,
    hud = { scale = 1, x = 0, y = 0, visible = true },
    diagnostics = false,
    bindings = { keyboardGoal = 117, keyboardToggle = 118, controllerGoal = 10, controllerToggle = 13 }
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
  if result.pinned == nil then result.pinned = false end
  result.pinned = result.pinned == true
  result.diagnostics = result.diagnostics == true
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

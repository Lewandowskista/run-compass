local Snapshot = {}
Snapshot.__index = Snapshot

local function clone(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = clone(item) end
  return result
end

function Snapshot.new(runtime)
  return setmetatable({ runtime = runtime }, Snapshot)
end

function Snapshot:build()
  local runtime = self.runtime
  return {
    currentRoom = runtime.getCurrentRoom(),
    mode = clone(runtime.getMode() or { kind = "normal", difficulty = "normal", coOp = false, progressionAllowed = true }),
    visibility = clone(runtime.getVisibility() or { curseBlind = false, curseLost = false }),
    player = clone(runtime.getPlayer() or {}),
    rooms = clone(runtime.getRooms() or {}),
    observations = clone(runtime.getObservations() or { pickups = {} }),
    timing = clone(runtime.getTiming and runtime.getTiming() or {})
  }
end

return Snapshot

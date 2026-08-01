local RouteState = {}

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = copy(item) end
  return result
end

local function currentRoom(snapshot)
  local currentId = snapshot and (snapshot.currentRoom or snapshot.floor and snapshot.floor.currentRoomId)
  for _, room in ipairs((snapshot and snapshot.rooms) or {}) do
    if room.id == currentId then return room end
  end
  return nil
end

function RouteState.fromSnapshot(snapshot)
  snapshot = snapshot or {}
  local floor = snapshot.floor or {}
  local run = snapshot.run or {}
  local inventory = snapshot.player and snapshot.player.inventory or {}
  local questItems = inventory.questItems or inventory.items or {}
  local state = {
    stage = floor.stage,
    stageType = floor.stageType,
    branch = inventory.branch,
    questPieces = copy(questItems),
    photoChoice = inventory.photoChoice,
    routeCards = copy(inventory.routeCards or {}),
    consumedPieces = copy(inventory.consumedPieces or {}),
    alternateOpeners = copy(inventory.alternateOpeners or {}),
    timers = { elapsed = run.elapsedSeconds or 0, hushDeadline = 30 * 60 },
    visibleSpecialDoors = {}
  }
  local room = currentRoom(snapshot)
  for _, door in ipairs((room and room.doors) or {}) do
    if door.kind == "special" or (door.cost and door.cost.unknown) then
      state.visibleSpecialDoors[#state.visibleSpecialDoors + 1] = {
        slot = door.slot,
        kind = door.kind or "unknown",
        cost = copy(door.cost or {}),
        confidence = door.confidence or "low"
      }
    end
  end
  return state
end

return RouteState

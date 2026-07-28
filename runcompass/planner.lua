local Planner = {}
local Visibility = require("runcompass.visibility")

local SUPPORTED_MODES = { normal = true, hard = true }

local function copySet(values)
  local result = {}
  for _, value in ipairs(values or {}) do result[value] = true end
  return result
end

local function buildRoomMap(rooms)
  local result = {}
  for _, room in ipairs(rooms or {}) do result[room.id] = room end
  return result
end

local function isVisible(room, visibility)
  if not room or room.hidden then return false end
  if room.secret then return false end
  if visibility.curseLost and not room.visited then return false end
  return true
end

local function pathResources(path, roomMap)
  local cost = { keys = 0, bombs = 0, coins = 0, health = 0 }
  for index = 2, #path do
    local room = roomMap[path[index]]
    for resource, amount in pairs(room.cost or {}) do
      cost[resource] = (cost[resource] or 0) + amount
    end
  end
  return cost
end

local function canAfford(snapshot, goal, cost)
  local available = snapshot.player or {}
  local required = goal.requiredResources or {}
  for resource, amount in pairs(cost) do
    local reserve = required[resource] or 0
    if (available[resource] or 0) - amount < reserve then return false end
  end
  return true
end

local function pathScore(path, roomMap, cost, visibility)
  local score = -(#path - 1) * 0.1
  score = score - (cost.keys or 0) * 20 - (cost.bombs or 0) * 8 - (cost.coins or 0) * 0.25 - (cost.health or 0) * 15
  for index = 2, #path - 1 do
    local room = roomMap[path[index]]
    for _, pickup in ipairs(Visibility.filterPickups(room.pickups or {}, visibility)) do
      if pickup.visible ~= false then score = score + (pickup.quality or 0) * 10 end
    end
    if room.kind == "shop" then score = score + 1 end
    if room.kind == "treasure" then score = score + 2 end
  end
  return score
end

local function enumeratePaths(snapshot, goal, roomMap)
  local destinations = copySet(goal.destinationRooms)
  local paths = {}
  local current = snapshot.currentRoom
  local seen = { [current] = true }
  local path = { current }

  local function visit(roomId)
    if destinations[roomId] then
      local cost = pathResources(path, roomMap)
      if canAfford(snapshot, goal, cost) then
        paths[#paths + 1] = { nodes = { table.unpack(path) }, cost = cost, score = pathScore(path, roomMap, cost, snapshot.visibility or {}) }
      end
      return
    end
    if #path >= 50 then return end
    local room = roomMap[roomId]
    for _, door in ipairs(room.doors or {}) do
      local nextRoom = roomMap[door.to]
      if nextRoom and not seen[door.to] and isVisible(nextRoom, snapshot.visibility or {}) then
        seen[door.to] = true
        path[#path + 1] = door.to
        visit(door.to)
        path[#path] = nil
        seen[door.to] = nil
      end
    end
  end

  visit(current)
  return paths
end

local function firstDoor(snapshot, roomMap, path)
  local first = roomMap[path[1]]
  for _, door in ipairs(first.doors or {}) do
    if door.to == path[2] then return door.slot end
  end
  return nil
end

local function recommendationForPath(snapshot, roomMap, candidate)
  local steps = {}
  for index = 2, math.min(#candidate.nodes, 4) do
    local room = roomMap[candidate.nodes[index]]
    steps[#steps + 1] = "Go to " .. (room.kind or "room")
  end
  if #steps == 0 then steps[1] = "Goal room reached" end
  return {
    status = "ok",
    nextDoorSlot = firstDoor(snapshot, roomMap, candidate.nodes),
    steps = steps,
    score = candidate.score,
    reasonCodes = {
      goal_feasible = true,
      resource_reservation = next(candidate.cost) ~= nil
    },
    confidence = "medium",
    capabilityTier = "base"
  }
end

function Planner.plan(snapshot, goal, previous)
  if goal.status == "instructional" then
    return { status = "instructional", steps = { "Install the catalog update or use Repentogon for this goal" }, reasonCodes = { catalog_update_required = true }, confidence = "none", capabilityTier = "base" }
  end
  if goal.status == "complete" then
    return { status = "complete", steps = { "Goal already complete" }, reasonCodes = { goal_complete = true }, confidence = "high", capabilityTier = "base" }
  end
  local mode = snapshot.mode or {}
  if not SUPPORTED_MODES[mode.kind] or mode.coOp or mode.progressionAllowed == false then
    return { status = "inactive", steps = {}, reasonCodes = { unsupported_mode = true }, confidence = "none", capabilityTier = "base" }
  end

  local roomMap = buildRoomMap(snapshot.rooms)
  local destinations = goal.destinationRooms or {}
  if #destinations == 0 and goal.frontier then
    local current = roomMap[snapshot.currentRoom]
    for _, door in ipairs(current and current.doors or {}) do
      if isVisible(roomMap[door.to], snapshot.visibility or {}) then
        return {
          status = "explore",
          nextDoorSlot = door.slot,
          steps = { "Explore the revealed route", "Replan when the target branch appears" },
          reasonCodes = { frontier_exploration = true },
          confidence = "low",
          capabilityTier = "base"
        }
      end
    end
  end
  local hiddenDestination = false
  for _, id in ipairs(destinations) do
    if not isVisible(roomMap[id], snapshot.visibility or {}) then hiddenDestination = true end
  end

  local paths = enumeratePaths(snapshot, goal, roomMap)
  if #paths == 0 then
    local reasonCodes = { hidden_information = hiddenDestination }
    if (goal.requiredResources and next(goal.requiredResources)) then reasonCodes.resource_reservation = true end
    return { status = "unreachable", steps = {}, reasonCodes = reasonCodes, confidence = "low", capabilityTier = "base" }
  end

  table.sort(paths, function(left, right) return left.score > right.score end)
  local recommendation = recommendationForPath(snapshot, roomMap, paths[1])
  if previous and previous.status == "ok" and previous.nextDoorSlot == recommendation.nextDoorSlot then
    return previous
  end
  return recommendation
end

return Planner

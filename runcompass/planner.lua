local Planner = {}
local Visibility = require("runcompass.visibility")
local Milestones = require("runcompass.milestones")
local Search = require("runcompass.search")
local Valuation = require("runcompass.valuation")
local Frontier = require("runcompass.frontier")
local Recommendation = require("runcompass.recommendation")

local SUPPORTED_MODES = { normal = true, hard = true }

local function capabilityTier(snapshot)
  return snapshot and snapshot.capabilities and snapshot.capabilities.tier or "base"
end

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
    if not room then return cost end
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
    if not room then return end
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

local function doorExists(snapshot, slot)
  local roomMap = buildRoomMap(snapshot.rooms)
  local current = roomMap[snapshot.currentRoom]
  for _, door in ipairs(current and current.doors or {}) do
    if door.slot == slot and roomMap[door.to] then return true end
  end
  return false
end

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
    score = candidate.evaluation and candidate.evaluation.utility or candidate.score,
    scoreVector = candidate.evaluation,
    reasonCodes = {
      goal_feasible = true,
      resource_reservation = next(candidate.cost) ~= nil,
      bounded_search = candidate.boundedSearch == true
    },
    confidence = "medium",
    capabilityTier = capabilityTier(snapshot)
  }
end

function Planner.plan(snapshot, goal, previous, decisionModels)
  if goal.status == "instructional" then
    local reason = goal.requiredCapability == "enhanced" and "Install Repentogon 1.1.0+ to verify this goal" or goal.status == "instructional_only" and "Follow the unlock instructions before routing this goal" or "Install the catalog update before routing this goal"
    return { status = "instructional", steps = { reason }, reasonCodes = { catalog_update_required = goal.classification == "catalog_update_required", instructional_only = goal.classification == "instructional_only", enhanced_required = goal.requiredCapability == "enhanced" }, confidence = "none", capabilityTier = capabilityTier(snapshot) }
  end
  if goal.status == "prerequisite_redirect" then
    local character = snapshot.player and snapshot.player.characterToken
    local step = character and ("Switch to " .. tostring(goal.requiredCharacterToken) .. " for this unlock") or "Character identity is unavailable; choose this goal in a compatible run"
    return { status = "prerequisite_redirect", steps = { step }, reasonCodes = { prerequisite_character = true, character_unknown = character == nil }, confidence = "high", capabilityTier = capabilityTier(snapshot) }
  end
  if goal.status == "complete" then
    return { status = "complete", steps = { "Goal already complete" }, reasonCodes = { goal_complete = true }, confidence = "high", capabilityTier = capabilityTier(snapshot) }
  end
  local mode = snapshot.mode or {}
  if not SUPPORTED_MODES[mode.kind] or mode.coOp or mode.progressionAllowed == false then
    return { status = "inactive", steps = {}, reasonCodes = { unsupported_mode = true }, confidence = "none", capabilityTier = capabilityTier(snapshot) }
  end

  local milestone = Milestones.compile(goal, snapshot)
  if milestone.status == "unreachable" then
    return { status = "unreachable", steps = { "This route requirement is no longer available this run" }, reasonCodes = milestone.reasonCodes, confidence = "high", capabilityTier = capabilityTier(snapshot) }
  end
  local routedGoal = {}
  for key, value in pairs(goal) do routedGoal[key] = value end
  routedGoal.requiredResources = routedGoal.requiredResources or {}
  for resource, amount in pairs(milestone.requiredResources) do
    if (routedGoal.requiredResources[resource] or 0) < amount then routedGoal.requiredResources[resource] = amount end
  end
  goal = routedGoal

  local roomMap = buildRoomMap(snapshot.rooms)
  if not roomMap[snapshot.currentRoom] then
    return { status = "waiting", steps = { "Waiting for the current room graph to finish loading" }, reasonCodes = { room_graph_incomplete = true }, confidence = "none", capabilityTier = capabilityTier(snapshot) }
  end
  local destinations = goal.destinationRooms or {}
  for _, destination in ipairs(destinations) do
    if destination == snapshot.currentRoom and snapshot.currentRoomClear then
      return { status = "complete", steps = { "Goal room cleared" }, reasonCodes = { goal_room_cleared = true }, confidence = "high", capabilityTier = capabilityTier(snapshot) }
    end
  end
  if #destinations == 0 and goal.frontier then
    local candidate = Frontier.best(snapshot, goal)
    if candidate then
      local step = candidate.roomKind == "treasure" and "Take the treasure-room detour"
        or candidate.roomKind == "shop" and "Check the worthwhile shop route"
        or "Explore the best revealed frontier"
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
      recommendation = Recommendation.finalize(snapshot, goal, recommendation, milestone, decisionModels)
      if keepPrevious(snapshot, previous, recommendation) then return previous end
      return recommendation
    end
  end
  local hiddenDestination = false
  for _, id in ipairs(destinations) do
    if not isVisible(roomMap[id], snapshot.visibility or {}) then hiddenDestination = true end
  end

  local destinationSet = copySet(goal.destinationRooms)
  local beam = Search.beam(snapshot, goal, 12, 3)
  local beamDestination = beam.nodes[#beam.nodes]
  local beamCost = pathResources(beam.nodes, roomMap)
  local paths = {}
  for _, state in ipairs(beam.candidates or {}) do
    local destination = state.nodes[#state.nodes]
    if #state.nodes > 1 and destinationSet[destination] then
      local cost = pathResources(state.nodes, roomMap)
      local evaluation = Valuation.evaluate(snapshot, state.nodes, goal)
      if canAfford(snapshot, goal, cost) and evaluation.feasible then
        paths[#paths + 1] = { nodes = state.nodes, cost = cost, score = state.score, evaluation = evaluation, boundedSearch = true }
      end
    end
  end
  if #paths == 0 and #beam.nodes > 1 and destinationSet[beamDestination] and canAfford(snapshot, goal, beamCost) then
    paths[1] = { nodes = beam.nodes, cost = beamCost, score = beam.score, evaluation = Valuation.evaluate(snapshot, beam.nodes, goal), boundedSearch = true }
  end
  if #paths == 0 then
    for _, candidate in ipairs(enumeratePaths(snapshot, goal, roomMap)) do
      candidate.evaluation = Valuation.evaluate(snapshot, candidate.nodes, goal)
      paths[#paths + 1] = candidate
    end
  end
  if #paths == 0 then
    local reasonCodes = { hidden_information = hiddenDestination }
    if (goal.requiredResources and next(goal.requiredResources)) then reasonCodes.resource_reservation = true end
    return { status = "unreachable", steps = {}, reasonCodes = reasonCodes, confidence = "low", capabilityTier = capabilityTier(snapshot) }
  end

  table.sort(paths, function(left, right)
    if left.evaluation and right.evaluation then return Valuation.compare(left.evaluation, right.evaluation) > 0 end
    return left.score > right.score
  end)
  local recommendation = recommendationForPath(snapshot, roomMap, paths[1])
  recommendation = Recommendation.finalize(snapshot, goal, recommendation, milestone, decisionModels)
  if keepPrevious(snapshot, previous, recommendation) then return previous end
  return recommendation
end

return Planner

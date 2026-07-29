local Valuation = {}
local Visibility = require("runcompass.visibility")

local RESOURCE_NAMES = { "keys", "bombs", "coins", "health" }

local function roomMap(rooms)
  local result = {}
  for _, room in ipairs(rooms or {}) do result[room.id] = room end
  return result
end

function Valuation.newTotals()
  return { cost = { keys = 0, bombs = 0, coins = 0, health = 0, unknown = false }, buildGain = 0, risk = 0 }
end

function Valuation.cloneTotals(totals)
  local cost = totals.cost
  return {
    cost = { keys = cost.keys, bombs = cost.bombs, coins = cost.coins, health = cost.health, unknown = cost.unknown },
    buildGain = totals.buildGain,
    risk = totals.risk
  }
end

-- Applies one traversed edge and target room's contribution to running totals (cost, risk, raw
-- buildGain including treasure/shop bonuses and pickup-quality gains). Callers
-- that need per-path evaluation but not the missing-room short circuit (e.g.
-- incremental BFS accumulation) can call this directly per visited room.
function Valuation.accumulate(snapshot, room, goalRooms, totals, edgeCost)
  for resource, amount in pairs(edgeCost or {}) do
    if resource == "unknown" and amount then
      totals.cost.unknown = true
    elseif type(amount) == "number" then
      totals.cost[resource] = (totals.cost[resource] or 0) + amount
    end
  end
  if room.clear == false then totals.risk = totals.risk + (room.kind == "boss" and 2 or 1) end
  if not goalRooms[room.id] then
    if room.pickups and room.pickups[1] then
      for _, pickup in ipairs(Visibility.filterPickups(room.pickups, snapshot.visibility or {})) do
        totals.buildGain = totals.buildGain + (pickup.quality or 0) * 10
      end
    end
    if room.kind == "treasure" then totals.buildGain = totals.buildGain + 2 end
    if room.kind == "shop" then totals.buildGain = totals.buildGain + 1 end
  end
  return totals
end

-- Computes feasibility, resourceMargin, buildGain penalties, survivalRisk,
-- detour/time, and utility from accumulated totals and a path length (number
-- of nodes in the path, matching what `#nodes` would have been).
function Valuation.finalize(snapshot, goal, totals, pathLength)
  local cost, buildGain, risk = totals.cost, totals.buildGain, totals.risk
  local available, required = snapshot.player or {}, goal and goal.requiredResources or {}
  local resourceMargin, feasible = 0, true
  if cost.unknown then feasible, resourceMargin = false, -math.huge end
  -- `required` is empty for the common case (no resource requirements on this
  -- goal, e.g. frontier exploration): skip the per-resource margin scan
  -- entirely rather than iterating RESOURCE_NAMES only to discover nothing
  -- was required, since this runs once per ranked candidate.
  if next(required) ~= nil then
    resourceMargin = cost.unknown and -math.huge or nil
    local hasRequirement = false
    for _, resource in ipairs(RESOURCE_NAMES) do
      local margin = (available[resource] or 0) - (cost[resource] or 0) - (required[resource] or 0)
      if required[resource] then
        hasRequirement = true
        if margin < 0 then feasible = false end
        if not resourceMargin or margin < resourceMargin then resourceMargin = margin end
      end
    end
    if not hasRequirement and not cost.unknown then resourceMargin = 0 end
  end
  buildGain = buildGain - (cost.keys or 0) * 20 - (cost.bombs or 0) * 8 - (cost.coins or 0) * 0.25 - (cost.health or 0) * 15
  local maxHealth = math.max(1, available.maxHealth or available.health or 1)
  local survivalRisk = risk / maxHealth
  local detour, time = math.max(0, pathLength - 1), math.max(0, pathLength - 1)
  return {
    feasible = feasible,
    survivalRisk = survivalRisk,
    resourceMargin = resourceMargin,
    buildGain = buildGain,
    detour = detour,
    time = time,
    cost = cost,
    utility = buildGain - survivalRisk * 10 - detour * 0.1
  }
end

function Valuation.evaluate(snapshot, nodes, goal)
  local rooms = roomMap(snapshot.rooms)
  local totals = Valuation.newTotals()
  local goalRooms = {}
  for _, id in ipairs(goal and goal.destinationRooms or {}) do goalRooms[id] = true end
  for index = 2, #nodes do
    local source = rooms[nodes[index - 1]]
    local room = rooms[nodes[index]]
    if not source or not room then return { feasible = false, survivalRisk = math.huge, resourceMargin = -math.huge, buildGain = 0, detour = math.huge, time = math.huge } end
    local edgeCost = {}
    for _, door in ipairs(source.doors or {}) do
      if door.to == room.id then edgeCost = door.cost or {}; break end
    end
    Valuation.accumulate(snapshot, room, goalRooms, totals, edgeCost)
  end
  return Valuation.finalize(snapshot, goal, totals, #nodes)
end

-- Inlined rather than calling a shared per-field `cmp(a, b, higher)` helper:
-- this runs on every pairwise comparison during `Frontier.best`'s sort
-- (O(n log n) calls), so avoiding the extra function-call layer per field
-- meaningfully reduces interpreter overhead in that hot path while producing
-- identical results to the equivalent lower/higher-is-better comparisons.
function Valuation.compare(left, right)
  if left.feasible ~= right.feasible then return left.feasible and 1 or -1 end
  if left.survivalRisk ~= right.survivalRisk then
    return left.survivalRisk < right.survivalRisk and 1 or -1
  end
  if left.resourceMargin ~= right.resourceMargin then
    return left.resourceMargin > right.resourceMargin and 1 or -1
  end
  if left.buildGain ~= right.buildGain then
    return left.buildGain > right.buildGain and 1 or -1
  end
  if left.detour ~= right.detour then
    return left.detour < right.detour and 1 or -1
  end
  if left.time == right.time then return 0 end
  return left.time < right.time and 1 or -1
end

return Valuation

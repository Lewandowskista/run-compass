local Valuation = {}
local Visibility = require("runcompass.visibility")

local RESOURCE_NAMES = { "keys", "bombs", "coins", "health" }

local function roomMap(rooms)
  local result = {}
  for _, room in ipairs(rooms or {}) do result[room.id] = room end
  return result
end

function Valuation.evaluate(snapshot, nodes, goal)
  local rooms, cost = roomMap(snapshot.rooms), { keys = 0, bombs = 0, coins = 0, health = 0 }
  local buildGain, risk = 0, 0
  local goalRooms = {}
  for _, id in ipairs(goal and goal.destinationRooms or {}) do goalRooms[id] = true end
  for index = 2, #nodes do
    local room = rooms[nodes[index]]
    if not room then return { feasible = false, survivalRisk = math.huge, resourceMargin = -math.huge, buildGain = 0, detour = math.huge, time = math.huge } end
    for resource, amount in pairs(room.cost or {}) do cost[resource] = (cost[resource] or 0) + amount end
    if room.clear == false then risk = risk + (room.kind == "boss" and 2 or 1) end
    if not goalRooms[room.id] then
      for _, pickup in ipairs(Visibility.filterPickups(room.pickups or {}, snapshot.visibility or {})) do
        buildGain = buildGain + (pickup.quality or 0) * 10
      end
      if room.kind == "treasure" then buildGain = buildGain + 2 end
      if room.kind == "shop" then buildGain = buildGain + 1 end
    end
  end
  local available, required = snapshot.player or {}, goal and goal.requiredResources or {}
  local resourceMargin, feasible, hasRequirement = nil, true, false
  for _, resource in ipairs(RESOURCE_NAMES) do
    local margin = (available[resource] or 0) - (cost[resource] or 0) - (required[resource] or 0)
    if required[resource] then
      hasRequirement = true
      if margin < 0 then feasible = false end
      if not resourceMargin or margin < resourceMargin then resourceMargin = margin end
    end
  end
  if not hasRequirement then resourceMargin = 0 end
  buildGain = buildGain - (cost.keys or 0) * 20 - (cost.bombs or 0) * 8 - (cost.coins or 0) * 0.25 - (cost.health or 0) * 15
  local maxHealth = math.max(1, available.maxHealth or available.health or 1)
  local survivalRisk = risk / maxHealth
  local detour, time = math.max(0, #nodes - 1), math.max(0, #nodes - 1)
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

function Valuation.compare(left, right)
  local function cmp(a, b, higher)
    if a == b then return 0 end
    if higher then return a > b and 1 or -1 end
    return a < b and 1 or -1
  end
  if left.feasible ~= right.feasible then return left.feasible and 1 or -1 end
  return cmp(left.survivalRisk, right.survivalRisk, false) ~= 0 and cmp(left.survivalRisk, right.survivalRisk, false)
    or cmp(left.resourceMargin, right.resourceMargin, true) ~= 0 and cmp(left.resourceMargin, right.resourceMargin, true)
    or cmp(left.buildGain, right.buildGain, true) ~= 0 and cmp(left.buildGain, right.buildGain, true)
    or cmp(left.detour, right.detour, false) ~= 0 and cmp(left.detour, right.detour, false)
    or cmp(left.time, right.time, false)
end

return Valuation

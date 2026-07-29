local Edges = {}

function Edges.cost(door)
  return type(door and door.cost) == "table" and door.cost or {}
end

function Edges.weight(door)
  local weight = 1
  for resource, amount in pairs(Edges.cost(door)) do
    if resource == "unknown" and amount then
      weight = weight + 1000
    elseif type(amount) == "number" then
      weight = weight + amount * 0.01
    end
  end
  return weight
end

function Edges.context(snapshot, goal, spent)
  return {
    available = snapshot and snapshot.player or {},
    required = goal and goal.requiredResources or {},
    spent = spent or {}
  }
end

local function feasible(door, context)
  local cost = Edges.cost(door)
  if cost.unknown then return false end
  if not context then return true end
  local available, required, spent = context.available or {}, context.required or {}, context.spent or {}
  for resource, amount in pairs(cost) do
    if type(amount) == "number"
        and (available[resource] or 0) - (spent[resource] or 0) - amount < (required[resource] or 0) then
      return false
    end
  end
  for resource, reserve in pairs(required) do
    local amount = type(cost[resource]) == "number" and cost[resource] or 0
    if type(reserve) == "number"
        and (available[resource] or 0) - (spent[resource] or 0) - amount < reserve then
      return false
    end
  end
  return true
end

local function better(candidate, current, context)
  if not current then return true end
  local candidateFeasible, currentFeasible = feasible(candidate, context), feasible(current, context)
  if candidateFeasible ~= currentFeasible then return candidateFeasible end
  local candidateWeight, currentWeight = Edges.weight(candidate), Edges.weight(current)
  if candidateWeight ~= currentWeight then return candidateWeight < currentWeight end
  local candidateSlot, currentSlot = tonumber(candidate.slot), tonumber(current.slot)
  return candidateSlot ~= nil and currentSlot ~= nil and candidateSlot < currentSlot
end

function Edges.best(room, target, context)
  local best
  for _, door in ipairs(room and room.doors or {}) do
    if door.to == target and better(door, best, context) then best = door end
  end
  return best
end

function Edges.bestDoors(room, context)
  local result, positions = {}, {}
  for _, door in ipairs(room and room.doors or {}) do
    local position = positions[door.to]
    if not position then
      result[#result + 1] = door
      positions[door.to] = #result
    elseif better(door, result[position], context) then
      result[position] = door
    end
  end
  return result
end

return Edges

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

function Edges.feasible(door, context)
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
  local candidateFeasible, currentFeasible = Edges.feasible(candidate, context), Edges.feasible(current, context)
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
    if Edges.feasible(door, context) then
      local position = positions[door.to]
      if not position then
        result[#result + 1] = door
        positions[door.to] = #result
      elseif better(door, result[position], context) then
        result[position] = door
      end
    end
  end
  return result
end

function Edges.feasibleDoors(room, context)
  local result = {}
  for _, door in ipairs(room and room.doors or {}) do
    if Edges.feasible(door, context) then result[#result + 1] = door end
  end
  return result
end

function Edges.addCost(spent, door)
  local result = {}
  for resource, amount in pairs(spent or {}) do result[resource] = amount end
  for resource, amount in pairs(Edges.cost(door)) do
    if resource == "unknown" and amount then
      result.unknown = true
    elseif type(amount) == "number" then
      result[resource] = (result[resource] or 0) + amount
    end
  end
  return result
end

local function valueLess(left, right)
  if type(left) == "number" and type(right) == "number" then return left < right end
  return tostring(left) < tostring(right)
end

function Edges.materialize(state)
  if state.nodes and state.edges then return state.nodes, state.edges end
  local reversedNodes, reversedEdges = {}, {}
  local current = state
  while current do
    reversedNodes[#reversedNodes + 1] = current.roomId
    if current.edge then reversedEdges[#reversedEdges + 1] = current.edge end
    current = current.parent
  end
  local nodes, edges = {}, {}
  for index = #reversedNodes, 1, -1 do nodes[#nodes + 1] = reversedNodes[index] end
  for index = #reversedEdges, 1, -1 do edges[#edges + 1] = reversedEdges[index] end
  state.nodes, state.edges = nodes, edges
  return nodes, edges
end

function Edges.stateBefore(left, right)
  if left.distance ~= right.distance then return left.distance < right.distance end
  local leftNodes, leftEdges = Edges.materialize(left)
  local rightNodes, rightEdges = Edges.materialize(right)
  local length = math.min(#leftEdges, #rightEdges)
  for index = 1, length do
    local leftSlot, rightSlot = leftEdges[index].slot, rightEdges[index].slot
    if leftSlot ~= rightSlot then return valueLess(leftSlot, rightSlot) end
  end
  if #leftEdges ~= #rightEdges then return #leftEdges < #rightEdges end
  length = math.min(#leftNodes, #rightNodes)
  for index = 1, length do
    if leftNodes[index] ~= rightNodes[index] then return valueLess(leftNodes[index], rightNodes[index]) end
  end
  return #leftNodes < #rightNodes
end

local function dominates(left, right)
  if left.distance > right.distance then return false end
  local resources = {}
  for resource, amount in pairs(left.cost or {}) do if type(amount) == "number" then resources[resource] = true end end
  for resource, amount in pairs(right.cost or {}) do if type(amount) == "number" then resources[resource] = true end end
  local strict = left.distance < right.distance
  for resource in pairs(resources) do
    local leftAmount, rightAmount = left.cost[resource] or 0, right.cost[resource] or 0
    if leftAmount > rightAmount then return false end
    if leftAmount < rightAmount then strict = true end
  end
  if strict then return true end
  return not Edges.stateBefore(right, left)
end

function Edges.addLabel(labels, candidate)
  for _, existing in ipairs(labels) do
    if existing.active ~= false and dominates(existing, candidate) then return false end
  end
  for _, existing in ipairs(labels) do
    if existing.active ~= false and dominates(candidate, existing) then existing.active = false end
  end
  candidate.active = true
  labels[#labels + 1] = candidate
  return true
end

return Edges

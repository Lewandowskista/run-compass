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

local function better(candidate, current)
  if not current then return true end
  local candidateWeight, currentWeight = Edges.weight(candidate), Edges.weight(current)
  if candidateWeight ~= currentWeight then return candidateWeight < currentWeight end
  local candidateSlot, currentSlot = tonumber(candidate.slot), tonumber(current.slot)
  return candidateSlot ~= nil and currentSlot ~= nil and candidateSlot < currentSlot
end

function Edges.best(room, target)
  local best
  for _, door in ipairs(room and room.doors or {}) do
    if door.to == target and better(door, best) then best = door end
  end
  return best
end

function Edges.bestDoors(room)
  local result, positions = {}, {}
  for _, door in ipairs(room and room.doors or {}) do
    local position = positions[door.to]
    if not position then
      result[#result + 1] = door
      positions[door.to] = #result
    elseif better(door, result[position]) then
      result[position] = door
    end
  end
  return result
end

return Edges
